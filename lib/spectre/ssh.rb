require 'net/ssh'
require 'logger'


module Spectre
  module SSH
    class SSHConnection
      def initialize session, logger
        @logger = logger
        @session = session
        @exit_code = nil
        @output = ''
      end

      def file_exists path
        exec "ls #{path}"
        exit_code == 0
      end

      def owner_of path
        exec "ls -l #{path}"
        output.split(' ')[2]
      end

      def exec command
        log_str = "#{@session.options[:user]}@#{@session.host} -p #{@session.options[:port]} #{command}"

        @channel = @session.open_channel do |channel|
          channel.exec(command) do |ch, success|
            abort "could not execute #{command} on #{@session.host}" unless success

            channel.on_data do |ch, data|
              @output += data
            end

            channel.on_extended_data do |ch,type,data|
              @output += data
            end

            channel.on_request('exit-status') do |ch, data|
              @exit_code = data.read_long
            end

            # channel.on_request('exit-signal') do |ch, data|
            #   exit_code = data.read_long
            # end
          end

        end

        @channel.wait
        @session.loop

        log_str += "\n" + @output
        @logger.info log_str
      end

      def output
        @output
      end

      def exit_code
        @exit_code
      end
    end


    class << self
      def ssh name, &block
        raise "SSH connection '#{name}' not configured" unless @@cfg.has_key? name

        cfg = @@cfg[name]

        opts = {}
        opts[:port] = cfg['port'] || 22
        opts[:password] = cfg['password'] if cfg.has_key? 'password'
        opts[:keys] = [cfg['key']] if cfg.has_key? 'key'
        opts[:passphrase] = cfg['passphrase'] if cfg.has_key? 'passphrase'

        session = Net::SSH.start(cfg['host'], cfg['username'], opts)

        begin
          ssh_con = SSHConnection.new(session, @@logger)
          ssh_con.instance_eval &block
        ensure
          session.close
        end
      end
    end

    Spectre.register do |config|
      if config.has_key? 'ssh'
        @@logger = ::Logger.new File.join(config['log_path'], 'ssh.log'), progname: self.name

        @@cfg = {}

        config['ssh'].each do |name, cfg|
          @@cfg[name] = cfg
        end
      end
    end

    Spectre.delegate :ssh, to: self
  end
end