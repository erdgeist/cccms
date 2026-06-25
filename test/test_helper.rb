ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'rails/test_help'

module ActiveRecord
  class FixtureSet
    class << self
      alias_method :original_create_fixtures, :create_fixtures
      def create_fixtures(*args)
        original_create_fixtures(*args)
      rescue => e
        puts "\nFIXTURE ERROR: #{e.class}: #{e.message}"
        puts e.backtrace.first(20).join("\n")
        raise
      end
    end
  end
end

class Integer
  def days
    ActiveSupport::Duration.new(self * 86400, [[:days, self]])
  end
  alias :day :days

  def weeks
    ActiveSupport::Duration.new(self * 7 * 86400, [[:days, self * 7]])
  end
  alias :week :weeks

  def hours
    ActiveSupport::Duration.new(self * 3600, [[:seconds, self * 3600]])
  end
  alias :hour :hours

  def minutes
    ActiveSupport::Duration.new(self * 60, [[:seconds, self * 60]])
  end
  alias :minute :minutes

  def seconds
    ActiveSupport::Duration.new(self, [[:seconds, self]])
  end
  alias :second :seconds

  def months
    ActiveSupport::Duration.new(self * 30 * 86400, [[:months, self]])
  end
  alias :month :months

  def years
    ActiveSupport::Duration.new((self * 365.25 * 86400).to_i, [[:years, self]])
  end
  alias :year :years
end

class Float
  def days
    ActiveSupport::Duration.new((self * 86400).to_i, [[:days, self]])
  end
  alias :day :days

  def hours
    ActiveSupport::Duration.new((self * 3600).to_i, [[:seconds, (self * 3600).to_i]])
  end
  alias :hour :hours

  def minutes
    ActiveSupport::Duration.new((self * 60).to_i, [[:seconds, (self * 60).to_i]])
  end
  alias :minute :minutes
end

require 'arel'
module Arel
  module Visitors
    [ToSql, DepthFirst].each do |visitor|
      visitor.class_eval do
        def visit_Integer(o, collector = nil)
          collector ? collector << o.to_s : o.to_s
        end
      end
    end
  end
end

class ActiveSupport::TestCase
  
  include AuthenticatedTestHelper
  
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually 
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  
  def create_node_with_published_page
    node = create_node_with_draft
    draft = node.draft
    draft.title = "Test"
    draft.abstract = "Test"
    draft.body = "Test"
    draft.user = users(:quentin)
    node.publish_draft!
    node
  end
  
  def create_node_with_draft
    Node.root.children.create :slug => "test_node"
  end
end
