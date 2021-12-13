require_relative '../spectre'

require 'net/http'
require 'openssl'
require 'json'
require 'securerandom'
require 'logger'
require 'ostruct'

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
      'timeout' => 180,
    }

    @@modules = []

    class HttpError < Exception
      def initialize message
        super message
      end
    end

    class SpectreHttpRequest < Spectre::DslClass
      class Headers
        CONTENT_TYPE = 'Content-Type'
        UNIQUE_HEADERS = [CONTENT_TYPE].freeze
      end

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

      def timeout seconds
        @__req['timeout'] = seconds
      end

      def header name, value
        @__req['headers'] ||= []
        @__req['headers'].append [name, value.to_s.strip]
      end

      def param name, value
        @__req['query'] ||= []
        @__req['query'].append [name, value.to_s.strip]
      end

      def content_type media_type
        @__req['content_type'] = media_type
      end

      def json data
        data = data.to_h if data.is_a? OpenStruct
        body JSON.pretty_generate(data)

        # TODO: Only set content type, if not explicitly set
        content_type('application/json')
      end

      def body body_content
        @__req['body'] = body_content.to_s
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

      def no_auth!
        @__req['auth'] = 'none'
      end

      def certificate path
        @__req['cert'] = path
      end

      def use_ssl!
        @__req['use_ssl'] = true
      end

      def to_s
        @__req.to_s
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
        return nil unless @headers.key?(key.downcase)

        @headers[key.downcase].first
      end

      def to_s
        @headers.to_s
      end
    end

    class SpectreHttpResponse
      attr_reader :code, :message, :headers, :body

      def initialize net_res
        @code = net_res.code.to_i
        @message = net_res.message
        @body = net_res.body
        @headers = SpectreHttpHeader.new(net_res.to_hash)
        @json_data = nil
      end

      def json
        if !@body.nil? and @json_data.nil?
          begin
            @json_data = JSON.parse(@body, object_class: OpenStruct)
          rescue JSON::ParserError
            raise HttpError.new("Body content is not a valid JSON:\n#{@body}")
          end
        end

        @json_data
      end

      def success?
        @code < 400
      end
    end


    class << self
      @@http_cfg = {}
      @@response = nil
      @@request = nil
      @@modules = []
      @@secure_keys = []

      def https name, &block
        http(name, secure: true, &block)
      end

      def http name, secure: false, &block
        req = DEFAULT_HTTP_CONFIG.clone

        if @@http_cfg.key? name
          req.deep_merge! @@http_cfg[name].deep_clone
          raise HttpError.new("No `base_url' set for HTTP client '#{name}'. Check your HTTP config in your environment.") unless req['base_url']
        else
          req['base_url'] = name
        end

        req['use_ssl'] = secure unless secure.nil?

        SpectreHttpRequest.new(req)._evaluate(&block) if block_given?

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
          json = JSON.parse(str)
          json.obfuscate!(@@secure_keys) unless @@debug

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

      def secure? key
        @@secure_keys.any? { |x| key.to_s.downcase.include? x.downcase }
      end

      def header_to_s headers
        s = ''
        headers.each_header.each do |header, value|
          value = '*****' if secure?(header) and not @@debug
          s += "#{header.to_s.ljust(30, '.')}: #{value.to_s}\n"
        end
        s
      end

      def invoke req
        @@request = nil

        # Build URI

        scheme = req['use_ssl'] ? 'https' : 'http'
        base_url = req['base_url']

        unless base_url.match /http(?:s)?:\/\//
          base_url = scheme + '://' + base_url
        end

        if req['path']
          base_url = base_url + '/' unless base_url.end_with? '/'
          base_url += req['path']
        end

        uri = URI(base_url)

        raise HttpError.new("'#{uri}' is not a valid uri") unless uri.host

        # Build query parameters

        uri.query = URI.encode_www_form(req['query']) unless not req['query'] or req['query'].empty?

        # Create HTTP client

        net_http = Net::HTTP.new(uri.host, uri.port)
        net_http.read_timeout = req['timeout']

        if uri.scheme == 'https'
          net_http.use_ssl = true

          if req.key? 'cert'
            raise HttpError.new("Certificate '#{req['cert']}' does not exist") unless File.exists? req['cert']

            net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            net_http.ca_file = req['cert']
          else
            net_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
        end

        # Create HTTP Request

        net_req = Net::HTTPGenericRequest.new(req['method'], true, true, uri)
        net_req.body = req['body']
        net_req.content_type = req['content_type'] if req['content_type'] and not req['content_type'].empty?

        if req['headers']
          req['headers'].each do |header|
            net_req[header[0]] = header[1]
          end
        end

        req_id = SecureRandom.uuid()[0..5]

        # Run HTTP modules

        @@modules.each do |mod|
          mod.on_req(net_http, net_req, req) if mod.respond_to? :on_req
        end

        # Log request

        req_log = "[>] #{req_id} #{req['method']} #{uri}\n"
        req_log += header_to_s(net_req)
        req_log += try_format_json(req['body'], pretty: true) if req['body'] != nil and not req['body'].empty?

        @@logger.info(req_log)

        # Request

        start_time = Time.now

        begin
          net_res = net_http.request(net_req)
        rescue SocketError => e
          raise HttpError.new("The request '#{req['method']} #{uri}' failed. Please check if the given URL '#{uri}' is valid and available or a corresponding HTTP config in the environment file exists. See log for more details. Original.\nOriginal error was: #{e.message}")
        rescue Net::ReadTimeout
          raise HttpError.new("HTTP timeout of #{net_http.read_timeout}s exceeded")
        end

        end_time = Time.now

        req['started_at'] = start_time
        req['finished_at'] = end_time

        # Run HTTP modules

        @@modules.each do |mod|
          mod.on_res(net_http, net_res, req) if mod.respond_to? :on_res
        end

        # Log response

        res_log = "[<] #{req_id} #{net_res.code} #{net_res.message} (#{end_time - start_time}s)\n"
        res_log += header_to_s(net_res)
        res_log += try_format_json(net_res.body, pretty: true) unless net_res.body.nil? or net_res.body.empty?

        @@logger.info(res_log)

        fail "Response code of #{req_id} did not indicate success: #{net_res.code} #{net_res.message}" if req['ensure_success'] and net_res.code.to_i >= 400

        # Set global request and response variables

        @@request = OpenStruct.new(req)
        @@request.freeze

        @@response = SpectreHttpResponse.new(net_res)
      end
    end

    Spectre.register do |config|
      @@logger = ::Logger.new(config['log_file'], progname: 'spectre/http')
      @@secure_keys = config['secure_keys'] || []
      @@debug = config['debug']

      if config.key? 'http'
        @@http_cfg = {}

        config['http'].each do |name, cfg|
          @@http_cfg[name] = cfg
        end
      end
    end

    Spectre.delegate :http, :https, :request, :response, to: self
  end
end
