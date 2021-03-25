module Spectre::Http
  class SpectreHttpRequest
    def basic_auth username, password
      @__req['basic_auth'] = {} if not @__req.has_key? 'basic_auth'

      @__req['basic_auth']['username'] = username
      @__req['basic_auth']['password'] = password

      @__req['auth'] = 'basic_auth'
    end
  end

  module BasicAuth
    def self.on_req req, cmd
      return unless req.has_key? 'basic_auth' and req['auth'] == 'basic_auth'

      basic_auth_cfg = req['basic_auth']

      username = req['basic_auth']['username']
      password = req['basic_auth']['password']

      if username == nil or username.empty? or password == nil or password.empty?
        raise 'Username and password must not be empty if basic auth is used'
      end

      cmd.append '-u', "#{username}:#{password}"
    end

    Spectre::Http.register self
  end
end
