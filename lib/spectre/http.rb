require 'open3'
require 'ostruct'


module Spectre::Http
  class SpectreHttpRequest < Spectre::DslClass
    def initialize request
      @__req = request
    end

    def method method_name
      @__req['method'] = method_name
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
      @ensure_success = true
    end

    def ensure_success?
      @ensure_success
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

    def headers name
      return nil if !@res[:headers]
      @res[:headers][name.downcase]
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

      if req['cert'] or req['use_ssl']
        scheme = 'https'
      else
        scheme = 'http'
      end

      if @@http_cfg.has_key? name
        req.merge! @@http_cfg[name]
        raise "No `base_url' set for http client '#{name}'. Check your http config in your environment." if !req['base_url']
      else
        if not name.match /http(?:s)?:\/\//
          req['base_url'] = scheme + '://' + name
        else
          req['base_url'] = name
        end
      end

      SpectreHttpRequest.new(req).instance_eval(&block) if block_given?

      invoke req
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

    def invoke req
      cmd = [@@curl_path]

      uri = req['base_url']

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

      cmd.append uri
      cmd.append '-X', req['method']

      req['headers'].each do |header|
        cmd.append '-H', '"' + header.join(':') + '"'
      end if req['headers']

      cmd.append '-d', req['body'] if req['body']

      if req['cert']
        cmd.append '--cacert', req['cert']
      elsif req['use_ssl']
        cmd.append '-k'
      end

      cmd.append '-i'
      cmd.append '-v'

      # Call all registered modules
      @@modules.each do |mod|
        mod.on_req(req, cmd) if mod.respond_to? :on_req
      end

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

      body = stdout.gets(nil)
      stdout.close

      output = stderr.gets(nil)
      stderr.close

      debug_log = output.lines
        .select { |x| x.start_with? '* ' }
        .map { |x| x.sub '* ', '' }

      debug_log.each { |x| @@logger.debug x }

      exit_code = wait_thr.value.exitstatus

      raise Exception.new "An error occured while executing curl:\n#{debug_log.join "\n"}" unless exit_code == 0

      # Parse protocol, version, status code and status message from response
      match = /^< (?<protocol>[A-Za-z0-9]+)\/(?<version>\d+\.?\d*) (?<code>\d+) (?<message>.*)/.match output

      raise "Unexpected curl output:\n#{output}" unless match

      res_headers = output.lines
        .select { |x| x.start_with? '< ' }
        .map { |x| /^< (?<header>[A-Za-z0-9-]+):\s*(?<value>.*)$/.match x }
        .select { |x| x != nil }
        .collect { |x| [x[:header].downcase, x[:value]] }

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

      res_log = "[<] #{req_id} #{res.code} #{res.message} (#{end_time - start_time}s)\n"
      res_headers.each do |header|
        res_log += "#{header[0].to_s.ljust(30, '.')}: #{header[1].to_s}\n"
      end
      res_log += res.body if res.body != nil and not res.body.empty?

      @@logger.info res_log

      @@response = SpectreHttpResponse.new res

      @@response
    end
  end

  Spectre.register do |config|
    @@logger = ::Logger.new config['log_file'], progname: 'spectre/curl'

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