require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      def create_database(name, options = {})
        options = options.reverse_merge(:encoding => "utf8")

        option_string = options.symbolize_keys.inject("") do |memo, (key, value)|
          memo + case key
          when :owner
            " OWNER = \"#{value}\""
          when :template
            " TEMPLATE = \"#{value}\""
          when :encoding
            " ENCODING = '#{value}'"
          when :tablespace
            " TABLESPACE = \"#{value}\""
          when :connection_limit
            " CONNECTION LIMIT = #{value}"
          else
            ""
          end
        end

        execute "CREATE DATABASE #{quote_table_name(name)}#{option_string}"
      end
    end
  end
end
