require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead.
  # Then, you can remove it from this and the functional test.
  include AuthenticatedTestHelper
  fixtures :users

  def test_should_create_user
    assert_difference 'User.count' do
      user = create_user
      assert !user.new_record?, "#{user.errors.full_messages.to_sentence}"
    end
  end

  def test_should_require_login
    assert_no_difference 'User.count' do
      u = create_user(:login => nil)
      assert u.errors[:login].any?
    end
  end

  def test_should_require_password
    assert_no_difference 'User.count' do
      u = create_user(:password => nil)
      assert u.errors[:password].any?
    end
  end

  def test_should_require_password_confirmation
    assert_no_difference 'User.count' do
      u = create_user(:password_confirmation => nil)
      assert u.errors[:password_confirmation].any?
    end
  end

  def test_should_require_email
    assert_no_difference 'User.count' do
      u = create_user(:email => nil)
      assert u.errors[:email].any?
    end
  end

  def test_should_reset_password
    users(:quentin).update(:password => 'new password', :password_confirmation => 'new password')
    assert_equal users(:quentin), User.authenticate('quentin', 'new password')
  end

  def test_should_not_rehash_password
    users(:quentin).update(:login => 'quentin2')
    assert_equal users(:quentin), User.authenticate('quentin2', 'monkey')
  end

  def test_should_authenticate_user
    assert_equal users(:quentin), User.authenticate('quentin', 'monkey')
  end

  def test_should_not_authenticate_wrong_password
    assert_nil User.authenticate("quentin", "wrong password")
  end

  def test_should_not_authenticate_unknown_user
    assert_nil User.authenticate("nosuchuser", "monkey")
  end

  def test_user_with_crypted_password_is_migrated_on_login
    user = users(:quentin)

    assert_nil user.password_digest

    assert User.authenticate("quentin", "monkey")

    user.reload

    assert_not_nil user.password_digest
    assert_nil user.crypted_password
    assert_nil user.salt
  end

  def test_new_user_uses_password_digest
    user = create_user

    assert_not_nil user.password_digest
    assert_nil user.crypted_password
    assert_nil user.salt

    assert_equal user, User.authenticate("quire", "quire69")
  end

  def test_legacy_user_is_migrated_on_login
    user = users(:quentin)

    assert_nil user.password_digest
    assert_not_nil user.crypted_password
    assert_not_nil user.salt

    assert_equal user, User.authenticate("quentin", "monkey")

    user.reload

    assert_not_nil user.password_digest
    assert_nil user.crypted_password
    assert_nil user.salt
  end

  def test_migrated_user_authenticates_using_password_digest
    user = users(:quentin)

    # Trigger automatic migration.
    assert_equal user, User.authenticate("quentin", "monkey")

    user.reload

    assert_not_nil user.password_digest
    assert_nil user.crypted_password
    assert_nil user.salt

    # Second login should now use password_digest.
    assert_equal user, User.authenticate("quentin", "monkey")
  end
  
protected
  def create_user(options = {})
    record = User.new({ :login => 'quire', :email => 'quire@example.com', :password => 'quire69', :password_confirmation => 'quire69' }.merge(options))
    record.save
    record
  end
end
