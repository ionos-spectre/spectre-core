require 'net/http'
require 'openssl'
require 'json'
require 'securerandom'
require 'logger'


class ::Net::HTTPResponse
  def json
    if @data == nil
      @data = JSON.parse(self.body, object_class: OpenStruct)
    end
    @data
  end
end


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
    @body = JSON.parse(data)
  end
end


def http name, &block
  client_cfg = HTTP_CFG[name]
  base_uri = URI(client_cfg['base_url'])

  req = HttpRequest.new
  req.instance_eval(&block)

  uri = URI.join(base_uri, req.url_path)
  uri.query = URI.encode_www_form(req.params) unless req.params.empty?

  net_http = Net::HTTP.new(base_uri.host, base_uri.port)
  # net_http.verify_mode = OpenSSL::SSL::VERIFY_NONE

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

  LOGGER.debug(req_log)

  # Request
  
  start_time = Time.now

  $res = net_http.request(net_req)
  
  end_time = Time.now

  # Log response

  res_log = "[<] #{req_id} #{$res.code} #{$res.message} (#{end_time - start_time}s)\n"
  $res.each_header do |header, value|
    res_log += "#{header.to_s.ljust(30, '.')}: #{value}\n"
  end

  # Log response body
  if $res.body != nil && $res.body != ''
    begin
      response_content = JSON.pretty_generate(JSON.parse $res.body)
    rescue
      response_content = $res.body
    end
    res_log += response_content
  end

  LOGGER.debug(res_log)
end


def response
  $res
end


LOGGER = Logger.new File.join(SPEC_CFG['log_path'], 'http.log'), progname: 'http'

HTTP_CFG = {}

SPEC_ENV['http'].each do |name, cfg|
  HTTP_CFG[name] = cfg
end

$res = nil
