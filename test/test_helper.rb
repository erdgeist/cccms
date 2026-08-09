ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'rails/test_help'

# rails/test_help calls maintain_test_schema!, which reloads db/schema.rb
# in this process when a migration is pending. That recreates
# page_translations and drops the search_vector trigger the initializer
# installed at boot. Reinstall it here, after any such reload.
Page.ensure_search_vector_trigger!

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
  self.use_transactional_tests = true

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  setup do
    I18n.locale = I18n.default_locale
  end

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
    node = Node.root.children.create! :slug => "test_node"
    node.reload
    node
  end

  def find_or_create_draft(node, user)
    node.lock_for_editing!(user)
    node.draft || node.create_new_draft(user)
  end
end
