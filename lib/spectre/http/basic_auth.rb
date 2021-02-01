class HttpRequest
  def basic_auth username, password
    @config['basic_auth'] = {} if not @config.has_key? 'basic_auth'

    @config['basic_auth']['username'] = username
    @config['basic_auth']['password'] = password

    @config.config['auth'] = 'basic_auth'
  end
end


module Spectre::Http::BasicAuth
  def self.on_req http, req, req_opts
    return unless req_opts.config.has_key? 'basic_auth' and req_opts.config['auth'] == 'basic_auth'
    basic_auth_cfg = req_opts.config['basic_auth']
    req.basic_auth(basic_auth_cfg['username'], basic_auth_cfg['password'])
  end

  Spectre::Http.register(self)
end
