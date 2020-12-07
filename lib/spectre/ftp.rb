require 'net/ftp'
require 'logger'


module Spectre
  module FTP
    @@cfg = {}

    class FTPConnection
      def initialize session, logger
        @logger = logger
        @session = session
      end

      def download remotefile, localfile=File.basename(localfile)
        @logger.info "Downloading #{File.join @session.pwd, remotefile} to #{File.expand localfile}"
        @session.getbinaryfile(remotefile, localfile)
      end

      def upload localfile, remotefile=File.basename(localfile)
        @logger.info "Uploading #{File.expand localfile} to #{File.join @session.pwd, remotefile}"
        @session.putbinaryfile(localfile, remotefile)
      end

      def list
        file_list = @session.list
        @logger.info "Listing file in #{@session.pwd}\n#{file_list}"
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
        opts[:password] = password
        opts[:port] = config[:port] || cfg['port']

        @@logger.info "Connecting to #{host} with user #{username}"

        session = Net::FTP.start(host, opts)
        session.login

        begin
          ftp_con = FTPConnection.new(session, @@logger)
          ftp_con.instance_eval &block
        ensure
          session.close
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

    Spectre.delegate :ftp, to: self
  end
end