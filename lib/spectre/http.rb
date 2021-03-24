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

    class SpectreHttpHeader
      def initialize response
        @headers = {}

        response.each_header do |header, value|
          @headers[header.downcase] = value
        end
      end

      def [] key
        @headers[key.downcase]
      end

      def pretty
        @headers.pretty
      end
    end

    class SpectreHttpRequest < DslClass
      attr_reader :ensure_success

      def initialize config
        @config = config
      end

      def config
        @config.freeze
      end

      def method method_name
        @config['method'] = method_name
      end

      def path url_path
        @config['path'] = url_path
      end

      def header name, value
        @config['headers'] = {} if not @config['headers']
        @config['headers'][name] = value
      end

      def param name, value
        @config['query'] = {} if not @config['query']
        @config['query'][name] = value
      end

      def content_type media_type
        @config['content_type'] = media_type
      end

      def json data
        body JSON.pretty_generate(data)
        content_type 'application/json'
      end

      def body body_content
        @config['body'] = body_content
      end

      def ensure_success!
        @ensure_success = true
      end

      def authenticate method
        @config['auth'] = method
      end

      def certificate path
        @config['cert'] = path
        use_ssl
      end

      def use_ssl
        @config['ssl'] = true
      end

      alias_method :auth, :authenticate
      alias_method :cert, :certificate
      alias_method :media_type, :content_type
    end


    class SpectreHttpResponse
      def initialize res
        @res = {
          code: res.code,
          message: res.message,
          headers: SpectreHttpHeader.new(res),
          body: res.body,
        }

        @res.freeze

        @data = nil
      end

      def code
        @res[:code]
      end

      def message
        @res[:message]
      end

      def headers
        @res[:headers]
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

      def pretty
        @res.pretty
      end
    end


    class << self
      @@http_cfg = {}

      def http name, secure: false, &block
        invoke_req(name, secure ? 'https' : 'http', &block)
      end

      def https name, &block
        invoke_req(name, 'https', &block)
      end

      def invoke_req name, scheme, &block
        raise "`name' must not be nil or empty" if name == nil or name == ''

        @@request = nil

        req_config = DEFAULT_HTTP_CONFIG.clone

        if @@http_cfg.has_key? name
          req_config.merge! @@http_cfg[name]
          raise "No `base_url' set for http client '#{name}'. Check your http config in your environment." if !req_config['base_url']
        else
          if not name.match /http(?:s)?:\/\//
            req_config['base_url'] = scheme + '://' + name
          else
            req_config['base_url'] = name
          end
        end

        base_url = req_config['base_url']
        base_url = base_url + '/' if not base_url.end_with? '/'
        base_uri = URI(base_url)

        raise "'#{base_url}' is not a valid uri" if not base_uri.host

        req_config['host'] = base_uri.host
        req_config['port'] = base_uri.port

        spectre_req = SpectreHttpRequest.new req_config
        spectre_req.instance_eval(&block) if block_given?

        uri = URI.join(base_uri, spectre_req.config['path'])
        uri.query = URI.encode_www_form(spectre_req.config['query']) unless not spectre_req.config['query'] or spectre_req.config['query'].empty?

        net_http = Net::HTTP.new(uri.host, uri.port)

        if spectre_req.config['ssl'] or uri.scheme == 'https'
          net_http.use_ssl = true

          if spectre_req.config.has_key? 'cert'
            net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            net_http.ca_file = spectre_req.config['cert']
          else
            net_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
        end

        net_req = Net::HTTPGenericRequest.new(spectre_req.config['method'], true, true, uri)
        net_req.body = spectre_req.config['body']
        net_req.content_type = spectre_req.config['content_type'] if spectre_req.config['content_type'] and not spectre_req.config['content_type'].empty?

        if spectre_req.config['headers']
          spectre_req.config['headers'].each do |name, value|
            net_req[name] = value
          end
        end

        req_id = SecureRandom.uuid()[0..5]

        # Log request

        req_log = "[>] #{req_id} #{net_req.method} #{net_req.uri}\n"
        net_req.each_header do |header, value|
          req_log += "#{header.to_s.ljust(30, '.')}: #{value}\n"
        end
        req_log += net_req.body if net_req.body != nil and not net_req.body.empty?

        @@logger.info(req_log)

        # Request

        start_time = Time.now

        @@modules.each do |mod|
          mod.on_req(net_http, net_req, spectre_req) if mod.respond_to? :on_req
        end

        net_res = net_http.request(net_req)

        end_time = Time.now

        @@modules.each do |mod|
          mod.on_res(net_http, net_res, spectre_req) if mod.respond_to? :on_res
        end

        # Log response

        res_log = "[<] #{req_id} #{net_res.code} #{net_res.message} (#{end_time - start_time}s)\n"
        net_res.each_header do |header, value|
          res_log += "#{header.to_s.ljust(30, '.')}: #{value}\n"
        end

        # Log response body
        if net_res.body != nil and !net_res.body.empty?
          begin
            response_content = JSON.pretty_generate(JSON.parse net_res.body)
          rescue
            response_content = net_res.body
          end
          res_log += response_content
        end

        @@logger.info(res_log)

        if spectre_req.ensure_success
          code = Integer(net_res.code)
          fail "response code of #{req_id} did not indicate success: #{net_res.code} #{net_res.message}" if code >= 400
        end

        @@request = req_config
        @@response = SpectreHttpResponse.new net_res
      end


      def request
        @@request
      end


      def response
        @@response
      end


      def register mod
        @@modules << mod
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

    Spectre.delegate :http, :https, :request, :response, to: Http
  end
end