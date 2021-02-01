class HttpRequest
  def keystone url, username, password, project, domain, cert
    @config['keystone'] = {} if not @config.has_key? 'keystone'

    @config['keystone']['url'] = url
    @config['keystone']['username'] = username
    @config['keystone']['password'] = password
    @config['keystone']['project'] = project
    @config['keystone']['domain'] = domain
    @config['keystone']['cert'] = cert

    @config.config['auth'] = 'keystone'
  end
end


module Spectre::Http::Keystone
  @@cache = {}

  def self.on_req http, req, req_opts
    return unless req_opts.config.has_key? 'keystone' and req_opts.config['auth'] == 'keystone'

    keystone_cfg = req_opts.config['keystone']

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
