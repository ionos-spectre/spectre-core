require 'net/ftp'
require 'net/sftp'
require 'logger'
require 'json'


module Spectre
  module FTP
    @@cfg = {}

    class FTPConnection < DslClass
      def initialize host, username, password, opts, logger
        @__logger = logger
        @__session = nil

        @__host = host
        @__username = username
        @__password = password
        @__opts = opts
      end

      def connect!
        return unless @__session == nil or @__session.closed?
        @__logger.info "Connecting to '#{@__host}' with user '#{@__username}'"
        @__session = Net::FTP.new(@__host, @__opts)
        @__session.login @__username, @__password
      end

      def close
        return unless @__session and not @__session.closed?
        @__session.close
      end

      def can_connect?
        begin
          connect!
          return true
        rescue
          return false
        end
      end

      def download remotefile, to: File.basename(remotefile)
        connect!
        @__logger.info "Downloading '#{@__username}@#{@__host}:#{File.join @__session.pwd, remotefile}' to '#{File.expand_path to}'"
        @__session.getbinaryfile(remotefile, to)
      end

      def upload localfile, to: File.basename(localfile)
        connect!
        @__logger.info "Uploading '#{File.expand_path localfile}' to '#{@__username}@#{@__host}:#{File.join @__session.pwd, to}'"
        @__session.putbinaryfile(localfile, to)
      end

      def list
        connect!
        file_list = @__session.list
        @__logger.info "Listing file in #{@__session.pwd}\n#{file_list}"
        file_list
      end
    end


    class SFTPConnection < DslClass
      def initialize host, username, opts, logger
        @__logger = logger
        @__session = nil
        @__host = host
        @__username = username
        @__opts = opts
      end

      def connect!
        return unless @__session == nil or @__session.closed?
        @__logger.info "Connecting to '#{@__host}' with user '#{@__username}'"
        @__session = Net::SFTP.start(@__host, @__username, @__opts)
        @__session.connect!
      end

      def close
        return unless @__session and not @__session.closed?
        # @__session.close!
      end

      def can_connect?
        begin
          connect!
          return true
        rescue
          return false
        end
      end

      def download remotefile, to: File.basename(remotefile)
        @__logger.info "Downloading '#{@__username}@#{@__host}:#{remotefile}' to '#{File.expand_path to}'"
        connect!
        @__session.download!(remotefile, to)
      end

      def upload localfile, to: File.basename(localfile)
        @__logger.info "Uploading '#{File.expand_path localfile}' to '#{@__username}@#{@__host}:#{to}'"
        connect!
        @__session.upload!(localfile, to)
      end

      def stat path
        connect!
        file_info = @__session.stat! path
        @__logger.info "Stat '#{path}'\n#{JSON.pretty_generate file_info.attributes}"
        file_info.attributes
      end

      def exists path
        begin
          file_info = @__session.stat! path

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

        host = config[:host] || cfg['host'] || name
        username = config[:username] || cfg['username']
        password = config[:password] || cfg['password']

        opts = {}
        opts[:ssl] = config[:ssl]
        opts[:port] = config[:port] || cfg['port'] || 21

        @@logger.info "Connecting to #{host} with user #{username}"

        ftp_conn = FTPConnection.new(host, username, password, opts, @@logger)

        begin
          ftp_conn.instance_eval &block
        ensure
          ftp_conn.close
        end
      end

      def sftp name, config={}, &block
        raise "FTP connection '#{name}' not configured" unless @@cfg.has_key?(name) or config.count > 0

        cfg = @@cfg[name] || {}

        host = config[:host] || cfg['host'] || name
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

        sftp_con = SFTPConnection.new(host, username, opts, @@logger)

        begin
          sftp_con.instance_eval &block
        ensure
          sftp_con.close
        end
      end
    end

    Spectre.register do |config|
      @@logger = ::Logger.new config['log_file'], progname: 'spectre/ftp'

      if config.has_key? 'ftp'

        config['ftp'].each do |name, cfg|
          @@cfg[name] = cfg
        end
      end
    end

    Spectre.delegate :ftp, :sftp, to: self
  end
end