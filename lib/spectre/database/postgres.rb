require 'pg'


class PG::Result
  alias :count :ntuples
end


module Spectre
  module Database
    module Postgres
      @@modules = []

      class SQLStatement
        attr_accessor :query, :params

        def initialize
          @query = nil
          @params = []
        end

        def statement query
          @query = query
        end

        def param val
          @params << val
        end
      end


      class << self
        def postgres name, &block
          raise "postgres '#{name}' not configured" unless @@db_cfg.has_key? name

          statement = SQLStatement.new
          statement.instance_eval &block

          cfg = @@db_cfg[name]

          begin
            con = PG.connect({
              host: cfg['host'],
              port: cfg['port'],
              dbname: cfg['database'],
              user: cfg['username'],
              password: cfg['username'],
            })

            if statement.params
              @@result = con.exec_params(statement.query, statement.params)
            else
              @@result = con.exec(statement.query)
            end

          ensure
            con.close if con
          end
        end


        def result
          @@result
        end
      end

      Spectre.register do |config|
        @@db_cfg = {}

        config['postgres'].each do |name, cfg|
          @@db_cfg[name] = cfg
        end
      end

      Spectre.delegate :postgres, :result, to: self
    end
  end
end