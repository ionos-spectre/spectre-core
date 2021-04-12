class HttpRequest
  def keystone url, username, password, project, domain, cert
    @__req['keystone'] = {} if not @__req.has_key? 'keystone'

    @__req['keystone']['url'] = url
    @__req['keystone']['username'] = username
    @__req['keystone']['password'] = password
    @__req['keystone']['project'] = project
    @__req['keystone']['domain'] = domain
    @__req['keystone']['cert'] = cert

    @__req.config['auth'] = 'keystone'
  end
end


module Spectre::Http::Keystone
  @@cache = {}

  def self.on_req http, net_req, req
    return unless req.has_key? 'keystone' and req['auth'] == 'keystone'

    keystone_cfg = req['keystone']

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

    net_req['X-Auth-Token'] = token
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

    keystone_url = keystone_url + '/' if !keystone_url.end_with? '/'

    base_uri = URI(keystone_url)
    uri = URI.join(base_uri, 'auth/tokens?nocatalog=true')

    http = Net::HTTP.new(base_uri.host, base_uri.port)

    if cert
      http.use_ssl = true
      http.ca_file = cert
    end

    req = Net::HTTP::Post.new(uri)
    req.body = JSON.pretty_generate(auth_data)
    req.content_type = 'application/json'

    res = http.request(req)

    raise "error while authenticating: #{res.code} #{res.message}\n#{res.body}" if res.code != '201'

    [
      res['X-Subject-Token'],
      JSON.parse(res.body),
    ]
  end

  Spectre::Http.register(self)
end
