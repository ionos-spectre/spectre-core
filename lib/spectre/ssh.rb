require 'net/ssh'
require 'logger'


module Spectre
  module SSH
    @@cfg = {}

    class SSHConnection < DslClass
      def initialize host, username, opts, logger
        @__logger = logger
        @__host = host
        @__username = username
        @__opts = opts
        @__session = nil
        @__exit_code = nil
        @__output = ''
      end

      def file_exists path
        exec "ls #{path}"
        exit_code == 0
      end

      def owner_of path
        exec "stat -c %U #{path}"
        output.chomp
      end

      def connect!
        return unless @__session == nil or @__session.closed?
        @__session = Net::SSH.start(@__host, @__username, @__opts)
      end

      def close
        return unless @__session and not @__session.closed?
        @__session.close
      end

      def can_connect?
        @__output = nil

        begin
          connect!
          @__session.open_channel.close
          @__output = "successfully connected to #{@__host} with user #{@__username}"
          @__exit_code = 0
          return true
        rescue Exception => e
          @__logger.error e.message
          @__output = "unable to connect to #{@__host} with user #{@__username}"
          @__exit_code = 1
        end

        return false
      end

      def exec command
        connect!

        log_str = "#{@__session.options[:user]}@#{@__session.host} -p #{@__session.options[:port]} #{command}"

        @channel = @__session.open_channel do |channel|
          channel.exec(command) do |ch, success|
            abort "could not execute #{command} on #{@__session.host}" unless success

            @__output = ''

            channel.on_data do |ch, data|
              @__output += data
            end

            channel.on_extended_data do |ch,type,data|
              @__output += data
            end

            channel.on_request('exit-status') do |ch, data|
              @__exit_code = data.read_long
            end

            # channel.on_request('exit-signal') do |ch, data|
            #   exit_code = data.read_long
            # end
          end

        end

        @channel.wait
        @__session.loop

        log_str += "\n" + @__output
        @__logger.info log_str
      end

      def output
        @__output
      end

      def exit_code
        @__exit_code
      end
    end


    class << self
      def ssh name, config = {}, &block
        raise "SSH connection '#{name}' not configured" unless @@cfg.has_key?(name) or config.count > 0

        cfg = @@cfg[name] || {}

        host = cfg['host'] || name
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

        ssh_con = SSHConnection.new(host, username, opts, @@logger)

        begin
          ssh_con.instance_eval &block
        ensure
          ssh_con.close
        end
      end
    end

    Spectre.register do |config|
      @@logger = ::Logger.new config['log_file'], progname: 'spectre/ssh'

      if config.has_key? 'ssh'
        config['ssh'].each do |name, cfg|
          @@cfg[name] = cfg
        end
      end
    end

    Spectre.delegate :ssh, to: self
  end
end