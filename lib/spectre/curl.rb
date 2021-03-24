require 'open3'
require 'ectoplasm'

module Spectre::Curl
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
      @__req['query'] = [] if not @config['query']
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

  DEFAULT_HTTP_REQUEST = {
    'method' => 'GET',  # -X, --request <cmd>
    'base_url' => nil,
    'path' => '',
    'headers' => [      # -H, --header <header/@file>
      ['X-Foo', 'bar']
    ],
    'query' => [
      ['foo', 'bar']
    ],
    'body' => nil,      # -d, --data <data>
    'cert' => nil,      # --cacert
    'follow' => false,  # -L, --location
    'username' => nil,  # -u, --user <user:password>
    'password' => nil,
    'use_ssl' => false, # -k
  }

  def self.curl name, &block
    req = DEFAULT_HTTP_REQUEST.clone

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

  def self.invoke req
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
      cmd.append '-H', header.join(':')
    end

    cmd.append '-d', req['body'] if req['body']

    if req['cert']
      cmd.append '--cacert', req['cert']
    elsif req['use_ssl']
      cmd.append '-k'
    end

    cmd.append '-v'

    sys_cmd = cmd.join ' '

    @@logger.info sys_cmd

    stdin, stdout, stderr, wait_thr = Open3.popen3(sys_cmd)

    body = stdout.gets(nil)
    stdout.close

    output = stderr.gets(nil)
    stderr.close

    debug_log = output.lines
      .select { |x| x.start_with? '* ' }
      .map { |x| x.sub '* ', '' }

    debug_log.each { |x| @@logger.debug x }

    exit_code = wait_thr.value.exitstatus

    if exit_code != 0
      raise Exception.new "An error occured while executing curl:\n#{debug_log.join "\n"}"
    end

    # Parse protocol, version, status code and status message from response
    match = /^< (?<protocol>[A-Za-z0-9]+)\/(?<version>\d+\.?\d*) (?<code>\d+) (?<message>.*)/.match output

    SpectreHttpResponse.new({
      protocol: match[:protocol],
      version: match[:version],
      code: match[:code].to_i,
      message: match[:message],
      headers: Hash[
        output.lines
          .select { |x| x.start_with? '< ' }
          .map { |x| /^< (?<header>[A-Za-z0-9-]+):\s*(?<value>.*)$/.match x }
          .select { |x| x != nil }
          .collect { |x| [x[:header].downcase, x[:value]] }
      ],
      body: body
    })
  end

  Spectre.register do |config|
    @@logger = ::Logger.new config['log_file'], progname: 'spectre/curl'

    @@curl_path = 'C:\\Tools\\curl-7.75.0-win64-mingw\\bin\\curl.exe'

    if config.has_key? 'http'
      @@http_cfg = {}

      config['http'].each do |name, cfg|
        @@http_cfg[name] = cfg
      end
    end
  end

  Spectre.delegate :curl, to: self
end