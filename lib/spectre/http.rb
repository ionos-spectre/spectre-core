require 'net/http'
require 'openssl'
require 'json'
require 'securerandom'
require 'logger'


class Net::HTTPResponse
  def json
    if @data == nil
      @data = JSON.parse(self.body, object_class: OpenStruct)
    end
    @data
  end
end


module Spectre
  module Http
    @@modules = []

    class HttpRequest
      attr_accessor :headers, :params, :body, :http_method, :url_path

      def initialize
        @headers = {}
        @params = {}
        @body = nil
      end

      def method method_name
        @http_method = method_name
      end

      def path url_path
        @url_path = url_path
      end

      def header name, value
        @headers[name] = value
      end

      def param name, value
        @params[name] = value
      end

      def json data
        @body = JSON.pretty_generate(data)
      end
    end


    class << self
      def http name, &block
        client_cfg = @@http_cfg[name]
        base_uri = URI(client_cfg['base_url'])

        req = HttpRequest.new
        req.instance_eval(&block)

        uri = URI.join(base_uri, req.url_path)
        uri.query = URI.encode_www_form(req.params) unless req.params.empty?

        net_http = Net::HTTP.new(base_uri.host, base_uri.port)

        if client_cfg.has_key? 'cert'
          net_http.use_ssl = true
          net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          net_http.ca_file = client_cfg['cert']
        else
          net_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        net_req = Net::HTTPGenericRequest.new(req.http_method, true, true, uri)
        net_req.body = req.body
        req.headers.each do |name, value|
          net_req[name] = value
        end

        req_id = SecureRandom.uuid()[0..5]

        # Log request

        req_log = "[>] #{req_id} #{net_req.method} #{net_req.uri}\n"
        net_req.each_header do |header, value|
          req_log += "#{header.to_s.ljust(30, '.')}: #{value}\n"
        end
        req_log += net_req.body if net_req.body != nil && net_req.body != ''

        @@logger.debug(req_log)

        # Request

        start_time = Time.now

        @@modules.each do |mod|
          mod.on_req(net_http, net_req, client_cfg) if mod.respond_to? :on_req
        end

        @@response = net_http.request(net_req)

        end_time = Time.now

        @@modules.each do |mod|
          mod.on_res(net_http, @@response, client_cfg) if mod.respond_to? :on_res
        end

        # Log response

        res_log = "[<] #{req_id} #{@@response.code} #{@@response.message} (#{end_time - start_time}s)\n"
        @@response.each_header do |header, value|
          res_log += "#{header.to_s.ljust(30, '.')}: #{value}\n"
        end

        # Log response body
        if @@response.body != nil && @@response.body != ''
          begin
            response_content = JSON.pretty_generate(JSON.parse @@response.body)
          rescue
            response_content = @@response.body
          end
          res_log += response_content
        end

        @@logger.debug(res_log)
      end


      def response
        @@response
      end


      def register mod
        @@modules << mod
      end

    end

    Spectre.register do |config|
      @@logger = ::Logger.new File.join(config['log_path'], 'http.log'), progname: self.name

      @@http_cfg = {}

      config['http'].each do |name, cfg|
        @@http_cfg[name] = cfg
      end

      @@response = nil
    end

    Spectre.delegate :http, :response, to: Http

  end
end