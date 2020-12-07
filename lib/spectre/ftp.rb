require 'net/ftp'
require 'net/sftp'
require 'logger'
require 'json'


module Spectre
  module FTP
    @@cfg = {}

    class FTPConnection
      def initialize session, logger
        @logger = logger
        @session = session
      end

      def download remotefile, localfile=File.basename(remotefile)
        @logger.info "Downloading #{File.join @session.pwd, remotefile} to #{File.expand_path localfile}"
        @session.getbinaryfile(remotefile, localfile)
      end

      def upload localfile, remotefile=File.basename(localfile)
        @logger.info "Uploading #{File.expand_path localfile} to #{File.join @session.pwd, remotefile}"
        @session.putbinaryfile(localfile, remotefile)
      end

      def list
        file_list = @session.list
        @logger.info "Listing file in #{@session.pwd}\n#{file_list}"
        file_list
      end
    end


    class SFTPConnection
      def initialize session, logger
        @logger = logger
        @session = session
      end

      def download remotefile, to: File.basename(remotefile)
        @logger.info "Downloading #{remotefile} to #{File.expand_path to}"
        @session.download!(remotefile, to)
      end

      def upload localfile, to: File.basename(localfile)
        @logger.info "Uploading #{File.expand_path localfile} to #{to}"
        @session.upload!(localfile, to)
      end

      def stat path
        file_info = @session.stat! path
        @logger.info "Stat '#{path}'\n#{JSON.pretty_generate file_info.attributes}"
        file_info.attributes
      end

      def exists path
        begin
          file_info = @session.stat! path

        rescue Net::SFTP::StatusException => e
          return false if e.description == 'no such file'
          raise e
        end

        return true
      end
    end


    class << self
      def ftp name, config={}, &block
        raise "FTP connection '#{name}' not configured" unless @@cfg.has_key?(name) or config.count > 0
        cfg = @@cfg[name] || {}

        host = config[:host] || cfg['host']
        username = config[:username] || cfg['username']
        password = config[:password] || cfg['password']

        opts = {}
        opts[:username] = username
        opts[:password] = password if password
        opts[:ssl] = config[:ssl]
        opts[:port] = config[:port] || cfg['port'] || 21

        @@logger.info "Connecting to #{host} with user #{username}"

        session = Net::FTP.new(host, opts)
        session.login username, password

        begin
          ftp_con = FTPConnection.new(session, @@logger)
          ftp_con.instance_eval &block
        ensure
          session.close
        end
      end

      def sftp name, config={}, &block
        raise "FTP connection '#{name}' not configured" unless @@cfg.has_key?(name) or config.count > 0

        cfg = @@cfg[name] || {}

        host = config[:host] || cfg['host']
        username = config[:username] || cfg['username']
        password = config[:password] || cfg['password']

        opts = {}
        opts[:password] = password
        opts[:port] = config[:port] || cfg['port'] || 22
        opts[:keys] = [cfg['key']] if cfg.has_key? 'key'
        opts[:passphrase] = cfg['passphrase'] if cfg.has_key? 'passphrase'

        opts[:auth_methods] = []
        opts[:auth_methods].push 'publickey' if opts[:keys]
        opts[:auth_methods].push 'password' if opts[:password]

        session = Net::SFTP.start(host, username, opts)

        begin
          sftp_con = SFTPConnection.new(session, @@logger)
          sftp_con.instance_eval &block
        ensure
          session.close session
        end
      end
    end

    Spectre.register do |config|
      if config.has_key? 'ftp'
        @@logger = ::Logger.new config['log_file'], progname: 'spectre/ftp'

        config['ftp'].each do |name, cfg|
          @@cfg[name] = cfg
        end
      end
    end

    Spectre.delegate :ftp, :sftp, to: self
  end
end