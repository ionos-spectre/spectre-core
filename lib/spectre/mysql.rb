module Spectre
  module MySQL

    class MySqlQuery < DslClass
      def initialize query
        @__query = query
      end

      def host hostname
        @__query['host'] = hostname
      end

      def password pass
        @__query['password'] = password
      end

      def database name
        @__query['database'] = name
      end

      def query statement
        @__query['query'] = query
      end
    end

    class << self
      @@mysql_cfg = {}
      @@result = nil

      def mysql name, &block
        query = {}

        if @@mysql_cfg.has_key? name
          query.merge! @@mysql_cfg[name]
          raise "No `host' set for MySQL client '#{name}'. Check your MySQL config in your environment." if !query['host']
        else
          query['host'] = name
        end

        client = Mysql2::Client.new(
          host: query['host'],
          username: query['username'],
          password: query['password'],
          database: query['database']
        )

        result = client.query(query['query'])

        @@result = result.map do |row| { OpenStruct.new row }
      end

      def result
        raise 'No MySQL query has been executed yet' unless @@result
        @@result
      end
    end

    Spectre.register do |config|
      @@logger = ::Logger.new config['log_file'], progname: 'spectre/mysql'

      if config.has_key? 'mysql'
        @@mysql_cfg = {}

        config['mysql'].each do |name, cfg|
          @@mysql_cfg[name] = cfg
        end
      end
    end

    Spectre.delegate :mysql, :result, to: self
  end
end