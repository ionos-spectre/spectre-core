module Spectre::Http
  class SpectreHttpRequest
    def basic_auth username, password
      @__req['basic_auth'] = {} if not @__req.key? 'basic_auth'

      @__req['basic_auth']['username'] = username
      @__req['basic_auth']['password'] = password

      @__req['auth'] = 'basic_auth'
    end
  end

  module BasicAuth
    def self.on_req http, net_req, req
      return unless req.key? 'basic_auth' and req['auth'] == 'basic_auth'

      basic_auth_cfg = req['basic_auth']
      net_req.basic_auth(basic_auth_cfg['username'], basic_auth_cfg['password'])
    end

    Spectre::Http.register(self)
  end
end
