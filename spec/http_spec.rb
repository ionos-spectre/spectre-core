require 'net/http'

def create_response code='200', message='Ok', body='{"message": "Hello World!"}'
  net_res = double(::Net::HTTPOK)
  allow(net_res).to receive(:code).and_return(code)
  allow(net_res).to receive(:message).and_return(message)
  allow(net_res).to receive(:body).and_return(body)
  allow(net_res).to receive(:each_header).and_return([['some-header', 'some-value']])
  allow(net_res).to receive(:to_hash).and_return({})

  net_res
end

RSpec.describe 'spectre/http' do
  context do
    before do
      require 'spectre/http'
      require 'spectre/http/basic_auth'
      require 'spectre/http/keystone'

      @net_http = double(::Net::HTTP)
      allow(@net_http).to receive(:read_timeout=)
      allow(@net_http).to receive(:max_retries=)
      allow(@net_http).to receive(:use_ssl=)
      allow(@net_http).to receive(:verify_mode=)

      net_res = create_response()
      allow(@net_http).to receive(:request).and_return(net_res)

      allow(::Net::HTTP).to receive(:new).and_return(@net_http)

      @net_req = double(::Net::HTTPGenericRequest)
      allow(@net_req).to receive(:body=)
      allow(@net_req).to receive(:basic_auth)
      allow(@net_req).to receive(:each_header).and_return([])
      allow(@net_req).to receive(:[]=)
      allow(@net_req).to receive(:content_type=)
      allow(::Net::HTTPGenericRequest).to receive(:new).and_return(@net_req)

      Spectre.configure({})
    end

    it 'does some general HTTP request' do
      expect(@net_req).to receive(:body=).with("{\n  \"message\": \"Hello Spectre!\"\n}")
      expect(@net_req).to receive(:[]=).with('foo', 'bar')
      expect(@net_req).to receive(:content_type=).with('application/json')

      expect(@net_http).to receive(:read_timeout=).with(100)
      expect(@net_http).to receive(:max_retries=).with(0)
      expect(@net_http).to receive(:request).with(@net_req)

      Spectre::Http.http 'some-url.de' do
        method 'POST'
        path '/some-resource'
        timeout 100
        header 'foo', 'bar'
        param 'bla', 'blubb'
        json({
          "message": "Hello Spectre!",
        })
      end

      expect(Spectre::Http.response.code).to eq(200)
      expect(Spectre::Http.response.json.message).to eq("Hello World!")
    end

    it 'does some HTTPS request' do
      expect(@net_http).to receive(:use_ssl=).with(true)
      expect(@net_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      expect(@net_http).to receive(:request).with(@net_req)

      Spectre::Http.https 'some-url.de' do
        path '/some-resource'
      end
    end

    it 'sets max retries and timeout' do
      expect(@net_http).to receive(:max_retries=).with(5)
      expect(@net_http).to receive(:read_timeout=).with(300)

      Spectre::Http.https 'some-url.de' do
        path '/some-resource'
        timeout 300
        retries 5
      end
    end

    it 'does some HTTPS request wit hgiven certificate' do
      cert_file = 'somecert.ca'

      File.write(cert_file, 'This is an autogenerated certificate dummy file for testing purposes. If you find me, delete me!')

      expect(@net_http).to receive(:use_ssl=).with(true)
      expect(@net_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
      expect(@net_http).to receive(:ca_file=).with(cert_file)
      expect(@net_http).to receive(:request).with(@net_req)

      Spectre::Http.https 'some-url.de' do
        path '/some-resource'
        cert cert_file
      end

      File.delete(cert_file)
    end

    it 'does some HTTPS request with https url' do
      expect(@net_http).to receive(:use_ssl=).with(true)
      expect(@net_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      expect(@net_http).to receive(:request).with(@net_req)

      Spectre::Http.http 'https://some-url.de' do
        path '/some-resource'
      end
    end

    it 'does some HTTPS request with SSL switch' do
      expect(@net_http).to receive(:use_ssl=).with(true)
      expect(@net_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      expect(@net_http).to receive(:request).with(@net_req)

      Spectre::Http.http 'some-url.de' do
        path '/some-resource'
        use_ssl!
      end
    end

    it 'does some HTTPS request with SSL switch' do
      expect(@net_http).to receive(:request).with(@net_req)

      Spectre.configure({
        'http' => {
          'some_client' => {
            'base_url' => 'some-url.de',
          },
        },
      })

      Spectre::Http.http 'some_client' do
        path '/some-resource'
      end
    end

    it 'does some HTTP request with basic auth' do
      username = 'dummy'
      password = 'somepass'

      expect(@net_http).to receive(:request).with(@net_req)
      expect(@net_req).to receive(:basic_auth).with(username, password)

      Spectre::Http.http 'some-url.de' do
        method 'POST'
        path '/some-resource'
        basic_auth username, password
      end
    end

    it 'does some HTTP request with configured basic auth' do
      username = 'dummy'
      password = 'somepass'

      expect(@net_http).to receive(:request).with(@net_req)
      expect(@net_req).to receive(:basic_auth).with(username, password)

      Spectre.configure({
        'http' => {
          'some_client' => {
            'base_url' => 'some-url.de',
            'basic_auth' => {
              'username' => username,
              'password' => password,
            },
          },
        },
      })

      Spectre::Http.http 'some_client' do
        method 'POST'
        path '/some-resource'
        auth 'basic_auth'
      end
    end

    it 'does not override HTTP config' do
      username = 'bla'
      password = 'blubb'

      expect(@net_http).to receive(:request).with(@net_req)
      expect(@net_req).to receive(:basic_auth).with(username, password)

      http_cfg = {
        'http' => {
          'some_client' => {
            'base_url' => 'some-url.de',
            'basic_auth' => {
              'username' => 'dummy',
              'password' => 'somepass',
            },
          },
        },
      }

      Spectre.configure(http_cfg)

      Spectre::Http.http 'some_client' do
        path '/some-resource'
        basic_auth username, password
      end

      expect(http_cfg['http']['some_client']['basic_auth']['username']).to eq('dummy')
    end

    it 'raise error with missing base URL' do
      Spectre.configure({
        'http' => {
          'some_client' => {},
        },
      })

      expect {
        Spectre::Http.http 'some_client' do
          path '/some-resource'
        end
      }.to raise_error(Spectre::Http::HttpError)
    end
  end

  before do
    require 'spectre/http'
    require 'spectre/http/basic_auth'
    require 'spectre/http/keystone'

    Spectre.configure({})
  end

  it 'does some HTTP request with keystone auth' do
    client = double(::Net::HTTP)
    allow(client).to receive(:read_timeout=)
    allow(client).to receive(:max_retries=)

    net_res = create_response('201', 'Created', '{}')
    allow(net_res).to receive(:[]).with('X-Subject-Token').and_return('somekeystonetoken')
    expect(client).to receive(:request).and_return(net_res) # first call returns keystone response
    expect(client).to receive(:request).and_return(net_res) # second call is actual http spectre request

    allow(::Net::HTTP).to receive(:new).and_return(client)

    Spectre::Http.http 'some-url.de' do
      method 'POST'
      path '/some-resource'
      keystone 'http://some-keystone-server.de/', 'dummy', 'somepass', 'foo', 'bar'
    end
  end
end
