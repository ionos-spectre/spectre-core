require 'net/http'
require 'openssl'
require 'json'
require 'securerandom'
require 'logger'
require 'ostruct'

require_relative '../spectre'


module Spectre::Http
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
    'content_type' => nil,
    'timeout' => 180,
    'retries' => 0,
  }

  class HttpError < Exception
  end

  class SpectreHttpRequest < Spectre::DslBase
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

    def retries count
      @__req['retries'] = count
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

      content_type('application/json') unless @__req['content_type']
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

    def no_log!
      @__req['no_log'] = true
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
    attr_reader :code, :message, :headers, :body, :json

    def initialize net_res
      @code = net_res.code.to_i
      @message = net_res.message
      @body = net_res.body
      @headers = SpectreHttpHeader.new(net_res.to_hash)
      @json = nil

      unless @body.nil?
        begin
          @json = JSON.parse(@body, object_class: OpenStruct)
        rescue JSON::ParserError
        end
      end
    end

    def success?
      @code < 400
    end
  end

  class HttpClient
    def initialize config, logger, modules
      @modules = modules
      @secure_keys = []
      @logger = logger
      @request = nil
      @response = nil
      @secure_keys = config['secure_keys'] || []
      @debug = config['debug']
      @config = config['http'] || {}
    end

    def https(name, &)
      http(name, secure: true, &)
    end

    def http name, secure: false, &block
      req = DEFAULT_HTTP_CONFIG.clone

      if @config.key? name
        req.deep_merge! @config[name].deep_clone
        raise HttpError.new("No `base_url' set for HTTP client '#{name}'. Check your HTTP config in your environment.") unless req['base_url']
      else
        req['base_url'] = name
      end

      req['use_ssl'] = secure unless secure.nil?

      SpectreHttpRequest.new(req)._evaluate(&block) if block_given?

      invoke(req)
    end

    def request
      raise 'No request has been invoked yet' unless @request

      @request
    end

    def response
      raise 'There is no response. No request has been invoked yet.' unless @response

      @response
    end

    private

    def try_format_json str, pretty: false
      return str unless str or str.empty?

      begin
        json = JSON.parse(str)
        json.obfuscate!(@secure_keys) unless @debug

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
      @secure_keys.any? { |x| key.to_s.downcase.include? x.downcase }
    end

    def header_to_s headers
      s = ''
      headers.each_header.each do |header, value|
        value = '*****' if secure?(header) and not @debug
        s += "#{header.to_s.ljust(30, '.')}: #{value.to_s}\n"
      end
      s
    end

    def invoke req
      @request = nil

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
      net_http.max_retries = req['retries']

      if uri.scheme == 'https'
        net_http.use_ssl = true

        if req['cert']
          raise HttpError.new("Certificate '#{req['cert']}' does not exist") unless File.exist? req['cert']

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

      @modules.each do |mod|
        mod.on_req(net_http, net_req, req) if mod.respond_to? :on_req
      end

      # Log request

      req_log = "[>] #{req_id} #{req['method']} #{uri}\n"
      req_log += header_to_s(net_req)

      unless req['body'].nil? or req['body'].empty?
        unless req['no_log']
          req_log += try_format_json(req['body'], pretty: true)
        else
          req_log += '[...]'
        end
      end

      @logger.info(req_log)

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

      @modules.each do |mod|
        mod.on_res(net_http, net_res, req) if mod.respond_to? :on_res
      end

      # Log response

      res_log = "[<] #{req_id} #{net_res.code} #{net_res.message} (#{end_time - start_time}s)\n"
      res_log += header_to_s(net_res)

      unless net_res.body.nil? or net_res.body.empty?
        unless req['no_log']
          res_log += try_format_json(net_res.body, pretty: true)
        else
          res_log += '[...]'
        end
      end

      @logger.info(res_log)

      fail "Response code of #{req_id} did not indicate success: #{net_res.code} #{net_res.message}" if req['ensure_success'] and net_res.code.to_i >= 400

      @request = OpenStruct.new(req).freeze
      @response = SpectreHttpResponse.new(net_res).freeze
    end
  end

  @@modules = []

  def self.register mod
    raise 'Module must not be nil' unless mod

    @@modules << mod
  end

  def self.create config, logger
    HttpClient.new(config, logger, @@modules)
  end
end

Spectre.define 'spectre/http' do |config, logger, _scope|
  register :http, :https, :request, :response do
    Spectre::Http.create(config, logger)
  end
end
