require 'open3'
require 'ostruct'


module Spectre::Http
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
      @__req['headers'].append [name, value]
    end

    def param name, value
      @__req['query'] = [] if not @__req['query']
      @__req['query'].append [name, value]
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
      @headers[key.downcase]
    end
  end

  class SpectreHttpResponse
    def initialize res
      @res = res
      @data = nil
    end

    def code
      @res[:code]
    end

    def message
      @res[:message]
    end

    def protocol
      @res[:protocol]
    end

    def version
      @res[:version]
    end

    def headers
      SpectreHttpHeader.new @res[:headers]
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

  # DEFAULT_HTTP_REQUEST = {
  #   'method' => 'GET',  # -X, --request <cmd>
  #   'base_url' => nil,
  #   'path' => nil,
  #   'headers' => nil,   # -H, --header <header/@file>
  #   'query' => nil,
  #   'body' => nil,      # -d, --data <data>
  #   'cert' => nil,      # --cacert
  #   'follow' => false,  # -L, --location
  #   'username' => nil,  # -u, --user <user:password>
  #   'password' => nil,
  #   'use_ssl' => false, # -k
  # }


  class << self
    @@http_cfg = {}
    @@response = nil
    @@request = nil
    @@modules = []

    def https name, &block
      http(name, secure: true, &block)
    end

    def http name, secure: false, &block
      req = {
        'use_ssl' => secure,
      }

      if @@http_cfg.has_key? name
        req.merge! @@http_cfg[name]
        raise "No `base_url' set for HTTP client '#{name}'. Check your HTTP config in your environment." if !req['base_url']
      else
        req['base_url'] = name
      end

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
      cmd = [@@curl_path]

      if req['cert'] or req['use_ssl']
        scheme = 'https'
      else
        scheme = 'http'
      end

      uri = req['base_url']

      if not uri.match /http(?:s)?:\/\//
        uri = scheme + '://' + uri
      end

      if req['path']
        uri += '/' if !uri.end_with? '/'
        uri += req['path']
      end

      if req['query']
        uri += '?'
        uri += req['query']
          .map { |x| x.join '='}
          .join '&'
      end

      cmd.append '"' + uri + '"'
      cmd.append '-X', req['method'] unless req['method'] == 'GET' or (req['body'] and req['method'] == 'POST')

      # Call all registered modules
      @@modules.each do |mod|
        mod.on_req(req, cmd) if mod.respond_to? :on_req
      end

      # Add headers to curl command
      req['headers'].each do |header|
        cmd.append '-H', '"' + header.map { |val| val.strip }.join(':') + '"'
      end if req['headers']

      # Add request body
      if req['body'] != nil and not req['body'].empty?
        req_body = try_format_json(req['body']).gsub(/"/, '\"')
        cmd.append '-d', '"' + req_body + '"'
      elsif ['POST', 'PUT', 'PATCH'].include? req['method'].upcase
        cmd.append '-d', '"\n"'
      end

      # Add certificate path if one if given
      if req['cert']
        raise "Certificate '#{req['cert']}' does not exist" unless File.exists? req['cert']
        cmd.append '--cacert', req['cert']
      elsif req['use_ssl'] or uri.start_with? 'https'
        cmd.append '-k'
      end

      cmd.append '-i'
      cmd.append '-v'

      @@request = OpenStruct.new req

      sys_cmd = cmd.join ' '

      @@logger.debug sys_cmd

      req_id = SecureRandom.uuid()[0..5]

      req_log = "[>] #{req_id} #{req['method']} #{uri}\n"
      req['headers'].each do |header|
        req_log += "#{header[0].to_s.ljust(30, '.')}: #{header[1].to_s}\n"
      end if req['headers']
      req_log += req['body'] if req['body'] != nil and not req['body'].empty?

      @@logger.info req_log

      start_time = Time.now

      stdin, stdout, stderr, wait_thr = Open3.popen3(sys_cmd)

      end_time = Time.now

      output = stdout.gets(nil)
      stdout.close

      debug_log = stderr.gets(nil)
      stderr.close

      debug_log.lines.each { |x| @@logger.debug x unless x.empty? }

      raise "Unable to request #{uri}. Please check if this service is reachable." unless output

      header, body = output.split "\n\n"

      result = header.lines.first

      exit_code = wait_thr.value.exitstatus

      raise Exception.new "An error occured while executing curl:\n#{debug_log.lines.map { |x| not x.empty? }}" unless exit_code == 0

      # Parse protocol, version, status code and status message from response
      match = /^(?<protocol>[A-Za-z0-9]+)\/(?<version>\d+\.?\d*) (?<code>\d+) (?<message>.*)/.match result

      raise "Unexpected result from curl request:\n#{result}" unless match

      res_headers = header.lines[1..-1]
        .map { |x| /^(?<key>[A-Za-z0-9-]+):\s*(?<value>.*)$/.match x }
        .select { |x| x != nil }
        .map { |x| [x[:key].downcase, x[:value]] }

      res = {
        protocol: match[:protocol],
        version: match[:version],
        code: match[:code].to_i,
        message: match[:message],
        headers: Hash[res_headers],
        body: body
      }

      # Call all registered modules
      @@modules.each do |mod|
        mod.on_res(res, output) if mod.respond_to? :on_res
      end

      res_log = "[<] #{req_id} #{res[:code]} #{res[:message]} (#{end_time - start_time}s)\n"
      res_headers.each do |header|
        res_log += "#{header[0].to_s.ljust(30, '.')}: #{header[1].to_s}\n"
      end

      if res[:body] != nil and not res[:body].empty?
        res_log += try_format_json(res[:body], pretty: true)
      end

      @@logger.info res_log

      @@response = SpectreHttpResponse.new res

      raise "Response did not indicate success: #{@@response.code} #{@@response.message}" if req['ensure_success'] and not @@response.success?

      @@response
    end
  end

  Spectre.register do |config|
    @@logger = ::Logger.new config['log_file'], progname: 'spectre/http'

    @@curl_path = config['curl_path'] || 'curl'

    if config.has_key? 'http'
      @@http_cfg = {}

      config['http'].each do |name, cfg|
        @@http_cfg[name] = cfg
      end
    end
  end

  Spectre.delegate :http, :https, :request, :response, to: self
end