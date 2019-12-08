module Spectre::Http::Keystone
  @@cache = {}

  def self.on_req http, req, cfg
    return unless cfg.has_key? 'keystone'

    keystone_cfg = cfg['keystone']

    if @@cache.has_key? keystone_cfg
      token = @@cache[keystone_cfg]
    else
      token, _ = authenticate(
        keystone_cfg['url'],
        keystone_cfg['username'],
        keystone_cfg['password'],
        keystone_cfg['project'],
        keystone_cfg['domain'],
        keystone_cfg['cert'],
      )

      @@cache[keystone_cfg] = token
    end

    req['X-Auth-Token'] = token
  end

  private

  def self.authenticate keystone_url, username, password, project, domain, cert
    auth_data = {
      auth: {
        identity: {
          methods: ['password'],
          password: {
            user: {
              name: username,
              password: password,
              domain: {
                name: domain,
              },
            },
          },
        },
        scope: {
          project: {
            name: project,
            domain: {
              name: domain,
            },
          },
        },
      },
    }

    base_uri = URI(keystone_url)
    uri = URI.join(base_uri, 'auth/tokens?nocatalog=true')
    http = Net::HTTP.new(base_uri.host, base_uri.port)
    req = Net::Request::POST.new(uri)
    req.body = JSON.pretty_generate(auth_data)

    res = http.request(req)

    raise "error while authenticating: #{res.code} #{res.message}\n#{res.body}" if res.code != '201'

    [
      response['X-Subject-Token'],
      JSON.parse(res.body),
    ]
  end
end
