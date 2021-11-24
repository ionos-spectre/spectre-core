require 'spectre'
require 'spectre/http/basic_auth'
require 'spectre/http/keystone'

def create_response code='200', message='Ok', body=''
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
      @client = double(::Net::HTTP)
      expect(@client).to receive(:read_timeout=).with(180)

      net_res = create_response()
      expect(@client).to receive(:request).and_return(net_res)

      allow(::Net::HTTP).to receive(:new).and_return(@client)
    end

    it 'does some general HTTP request' do
      Spectre.configure({})

      Spectre::Http.http 'some-url.de' do
        method 'POST'
        path '/some-resource'
        timeout 180
        header 'foo', 'bar'
        param 'bla', 'blubb'
        json({
          "message": "Hello Spectre!",
        })
      end
    end

    it 'does some HTTPS request' do
      expect(@client).to receive(:use_ssl=).with(true)
      expect(@client).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      Spectre.configure({})

      Spectre::Http.https 'some-url.de' do
        path '/some-resource'
      end
    end

    it 'does some HTTPS request with https url' do
      expect(@client).to receive(:use_ssl=).with(true)
      expect(@client).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      Spectre.configure({})

      Spectre::Http.http 'https://some-url.de' do
        path '/some-resource'
      end
    end

    it 'does some HTTPS request with SSL switch' do
      expect(@client).to receive(:use_ssl=).with(true)
      expect(@client).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      Spectre.configure({})

      Spectre::Http.http 'some-url.de' do
        path '/some-resource'
        use_ssl!
      end
    end

    it 'does some HTTPS request with SSL switch' do
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
      Spectre.configure({})

      Spectre::Http.http 'some-url.de' do
        method 'POST'
        path '/some-resource'
        basic_auth 'dummy', 'somepass'
      end
    end

    it 'does some HTTP request with configured basic auth' do
      Spectre.configure({
        'http' => {
          'some_client' => {
            'base_url' => 'some-url.de',
            'basic_auth' => {
              'username' => 'dummy',
              'password' => 'somepass',
            },
          },
        },
      })

      Spectre::Http.http 'some_client' do
        method 'POST'
        path '/some-resource'
      end
    end

    it 'does not override HTTP config' do
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
        basic_auth 'bla', 'blubb'
      end

      expect(http_cfg['http']['some_client']['basic_auth']['username']).to eq('dummy')
    end
  end

  context 'keystone' do
    it 'does some HTTP request with keystone auth' do
      client = double(::Net::HTTP)
      expect(client).to receive(:read_timeout=).with(180)

      net_res = create_response('201', 'Created', '{}')
      allow(net_res).to receive(:[]).with('X-Subject-Token').and_return('somekeystonetoken')
      expect(client).to receive(:request).and_return(net_res) # first call returns keystone response
      expect(client).to receive(:request).and_return(net_res) # second call is actual http spectre request

      allow(::Net::HTTP).to receive(:new).and_return(client)

      Spectre.configure({})

      Spectre::Http.http 'some-url.de' do
        method 'POST'
        path '/some-resource'
        keystone 'http://some-keystone-server.de/', 'dummy', 'somepass', 'foo', 'bar'
      end
    end
  end

  context 'config errors' do
    before do
      @client = double(::Net::HTTP)
      net_res = create_response()
      allow(::Net::HTTP).to receive(:new).and_return(@client)
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
      }.to raise_error(RuntimeError)
    end
  end
end
