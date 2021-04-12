require 'net/http'
require 'openssl'
require 'json'
require 'securerandom'
require 'logger'


module Spectre
  module Http
    DEFAULT_HTTP_CONFIG = {
      'method' => 'GET',
      'path' => '',
      'host' => nil,
      'port' => 80,
      'scheme' => 'http',
      'use_ssl' => false,
      'cert' => nil,
      'headers' => nil,
      'query' => nil,
      'content_type' => '',
    }

    @@modules = []

    class SpectreHttpRequest < Spectre::DslClass
      def initialize request
        @__req = request
      end

      def method method_name
        @__req['method'] = method_name.upcase
      end

      def url base_url
        @__req['base_url'] = base_url
      end

      def path url_path
        @__req['path'] = url_path
      end

      def header name, value
        @__req['headers'] = [] if not @__req['headers']
        @__req['headers'].append [name, value.to_s.strip]
      end

      def param name, value
        @__req['query'] = [] if not @__req['query']
        @__req['query'].append [name, value.to_s.strip]
      end

      def content_type media_type
        @__req['headers'] = [] if not @__req['headers']
        @__req['headers'].append ['Content-Type', media_type]
      end

      def json data
        body JSON.pretty_generate(data)
        content_type 'application/json'
      end

      def body body_content
        @__req['body'] = body_content
      end

      def ensure_success!
        @__req['ensure_success'] = true
      end

      def ensure_success?
        @__req['ensure_success']
      end

      def authenticate method
        @__req['auth'] = method
      end

      def certificate path
        @__req['cert'] = path
        use_ssl!
      end

      def use_ssl!
        @__req['use_ssl'] = true
      end

      alias_method :auth, :authenticate
      alias_method :cert, :certificate
      alias_method :media_type, :content_type
    end

    class SpectreHttpHeader
      def initialize headers
        @headers = headers || {}
      end

      def [] key
        @headers[key.downcase].first
      end
    end

    class SpectreHttpResponse
      def initialize res
        @res = res
        @data = nil
        @headers = SpectreHttpHeader.new @res[:headers]
      end

      def code
        @res[:code]
      end

      def message
        @res[:message]
      end

      def headers
        @headers
      end

      def body
        @res[:body]
      end

      def json
        return nil if not @res[:body]

        if @data == nil
          begin
            @data = JSON.parse(@res[:body], object_class: OpenStruct)
          rescue
            raise 'invalid json'
          end
        end

        @data
      end

      def success?
        @res[:code] < 400
      end

      def pretty
        @res.pretty
      end
    end


    class << self
      @@http_cfg = {}
      @@response = nil
      @@request = nil
      @@modules = []

      def https name, &block
        http(name, secure: true, &block)
      end

      def http name, secure: nil, &block
        req = {}

        if @@http_cfg.has_key? name
          req.merge! @@http_cfg[name]
          raise "No `base_url' set for HTTP client '#{name}'. Check your HTTP config in your environment." if !req['base_url']
        else
          req['base_url'] = name
        end

        req['user_ssl'] = secure if secure != nil

        SpectreHttpRequest.new(req).instance_eval(&block) if block_given?

        invoke(req)
      end

      def request
        raise 'No request has been invoked yet' unless @@request
        @@request
      end

      def response
        raise 'There is no response. No request has been invoked yet.' unless @@response
        @@response
      end

      def register mod
        raise 'Module must not be nil' unless mod
        @@modules << mod
      end

      private

      def try_format_json str, pretty: false
        return str unless str or str.empty?

        begin
          json = JSON.parse str

          if pretty
            str = JSON.pretty_generate(json)
          else
            str = JSON.dump(json)
          end
        rescue
          # do nothing
        end

        str
      end

      def invoke req
        @@request = nil

        if req['cert'] or req['use_ssl']
          scheme = 'https'
        else
          scheme = 'http'
        end

        base_url = req['base_url']

        if not base_url.match /http(?:s)?:\/\//
          base_url = scheme + '://' + base_url
        end

        if req['path']
          base_url = base_url + '/' if not base_url.end_with? '/'
          base_url += req['path']
        end

        uri = URI(base_url)

        raise "'#{uri}' is not a valid uri" if not uri.host

        uri.query = URI.encode_www_form(req['query']) unless not req['query'] or req['query'].empty?

        net_http = Net::HTTP.new(uri.host, uri.port)

        if uri.scheme == 'https'
          net_http.use_ssl = true

          if req.has_key? 'cert'
            raise "Certificate '#{req['cert']}' does not exist" unless File.exists? req['cert']
            net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            net_http.ca_file = req['cert']
          else
            net_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
        end

        net_req = Net::HTTPGenericRequest.new(req['method'], true, true, uri)
        net_req.body = req['body']
        net_req.content_type = req['content_type'] if req['content_type'] and not req['content_type'].empty?

        if req['headers']
          req['headers'].each do |header|
            net_req[header[0]] = header[1]
          end
        end

        req_id = SecureRandom.uuid()[0..5]

        # Log request

        req_log = "[>] #{req_id} #{req['method']} #{uri}"
        req['headers'].each do |header|
          req_log += "\n#{header[0].to_s.ljust(30, '.')}: #{header[1].to_s}"
        end if req['headers']
        req_log += "\n" + try_format_json(req['body'], pretty: true) if req['body'] != nil and not req['body'].empty?

        @@logger.info req_log

        # Request

        start_time = Time.now

        @@modules.each do |mod|
          mod.on_req(net_http, net_req, req) if mod.respond_to? :on_req
        end

        net_res = net_http.request(net_req)

        end_time = Time.now

        @@modules.each do |mod|
          mod.on_res(net_http, net_res, req) if mod.respond_to? :on_res
        end

        # Log response

        res_log = "[<] #{req_id} #{net_res.code} #{net_res.message} (#{end_time - start_time}s)\n"
        net_res.each_header do |header, value|
          res_log += "#{header.to_s.ljust(30, '.')}: #{value}\n"
        end
        res_log += try_format_json(net_res.body, pretty: true) if net_res.body != nil and !net_res.body.empty?

        @@logger.info(res_log)

        if req['ensure_success']
          code = Integer(net_res.code)
          fail "response code of #{req_id} did not indicate success: #{net_res.code} #{net_res.message}" if code >= 400
        end

        @@request = OpenStruct.new(req)
        @@response = SpectreHttpResponse.new({
          code: net_res.code.to_i,
          message: net_res.message,
          headers: net_res.to_hash,
          body: net_res.body
        })
      end
    end

    Spectre.register do |config|
      @@logger = ::Logger.new config['log_file'], progname: 'spectre/http'

      if config.has_key? 'http'
        @@http_cfg = {}

        config['http'].each do |name, cfg|
          @@http_cfg[name] = cfg
        end
      end
    end

    Spectre.delegate :http, :https, :request, :response, to: self
  end
end