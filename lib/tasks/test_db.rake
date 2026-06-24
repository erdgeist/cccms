namespace :db do
  namespace :test do
    task :load_schema do
      ActiveRecord::Base.establish_connection(:test)
      ActiveRecord::Schema.verbose = false
      load "#{Rails.root}/db/schema.rb"
    end

    task :prepare => :environment do
      begin
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::Base.connection
      rescue
        system("psql -U postgres postgres -c \"CREATE DATABASE psql_test OWNER psql ENCODING 'UTF8';\"")
      end
      Rake::Task['db:test:load_schema'].invoke
    end
  end
end
