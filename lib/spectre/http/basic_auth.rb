module Spectre::Http::BasicAuth
  def self.on_req http, req, cfg
    return unless cfg.has_key? 'basic_auth'
    basic_auth_cfg = cfg['basic_auth']
    req.basic_auth(basic_auth_cfg['username'], basic_auth_cfg['password'])
  end

  Spectre::Http.register(self)
end
