require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead.
  # Then, you can remove it from this and the functional test.
  include AuthenticatedTestHelper
  fixtures :users

  def role_entries
    NodeAction.where(:action => %w[admin_grant admin_revoke redaktion_grant
                                   redaktion_revoke user_deactivate user_reactivate])
  end

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

  def test_migrated_user_can_be_updated_without_password
    user = users(:quentin)
    assert_equal user, User.authenticate("quentin", "monkey")
    user.reload

    assert user.update(:email => "quentin@example.org")
  end

  test "may_change_live? gates restricted subjects on the redaktion role" do
    editor    = User.create!(:login => "gate_editor", :email => "ge@example.com",
                             :password => "secret", :password_confirmation => "secret")
    redaktion = User.create!(:login => "gate_red", :email => "gr@example.com",
                             :password => "secret", :password_confirmation => "secret",
                             :roles => ["redaktion"])

    restricted = Node.root
    plain = Node.root.children.create!(:slug => "gate_plain")

    assert     editor.may_change_live?(plain)
    assert_not editor.may_change_live?(restricted)
    assert     redaktion.may_change_live?(plain)
    assert     redaktion.may_change_live?(restricted)
  end

  test "amber needs a role to remove, red does not" do
    now   = Time.zone.parse("2026-08-03")
    roled = users(:redella)
    plain = users(:quentin)

    [roled, plain].each { |u| u.update_column(:last_login_at, now - 4.years) }

    assert_equal :amber, roled.staleness_tier(now)
    assert_nil plain.staleness_tier(now)

    [roled, plain].each { |u| u.update_column(:last_login_at, now - 11.years) }

    assert_equal :red, roled.staleness_tier(now)
    assert_equal :red, plain.staleness_tier(now), "dormant credentials are dormant whatever the roles"
  end

  test "staleness_tier boundaries" do
    now  = Time.zone.parse("2026-08-03")
    user = users(:redella)

    user.update_column(:last_login_at, now - 2.years - 11.months)
    assert_nil user.staleness_tier(now)

    user.update_column(:last_login_at, now - 3.years)
    assert_equal :amber, user.staleness_tier(now)

    user.update_column(:last_login_at, now - 9.years - 11.months)
    assert_equal :amber, user.staleness_tier(now)

    user.update_column(:last_login_at, now - 10.years)
    assert_equal :red, user.staleness_tier(now)
  end

  test "alumni are exempt, an account that never signed in is not" do
    now = Time.zone.parse("2026-08-03")

    alufa = users(:alufa)
    alufa.update_column(:last_login_at, now - 20.years)
    assert_nil alufa.staleness_tier(now), "alumni are the outcome, not a candidate"

    redella = users(:redella)
    redella.update_column(:last_login_at, nil)
    assert_equal :never, redella.staleness_tier(now)
  end

  test "granting a role through update_roles! is witnessed" do
    target = users(:redella)
    target.update_column(:otp_secret, ROTP::Base32.random)

    assert_difference -> { role_entries.count }, 1 do
      assert_empty target.update_roles!(%w[redaktion admin], :actor => users(:aaron))
    end

    assert_equal %w[admin redaktion], target.reload.roles.sort
    entry = role_entries.order(:id).last
    assert_equal "admin_grant", entry.action
    assert_equal users(:aaron).id, entry.user_id
    assert_equal "redella", entry.metadata["target_login"]
  end

  test "a refused grant applies nothing at all" do
    target = users(:quentin)
    assert_not target.otp_enrolled?

    assert_no_difference -> { role_entries.count } do
      refusals = target.update_roles!(%w[redaktion admin], :actor => users(:aaron))
      assert_includes refusals, :admin_needs_otp
      assert_includes refusals, :redaktion_needs_otp
    end

    assert_empty target.reload.roles, "a refusal must leave the stored set untouched"
  end

  test "nobody demotes themselves through update_roles!" do
    actor = users(:aaron)

    refusals = actor.update_roles!([], :actor => actor)

    assert_includes refusals, :admin_not_self
    assert_includes refusals, :redaktion_not_self
    assert_equal %w[admin redaktion], actor.reload.roles.sort
  end

  test "marking an account alumni through update_roles! is witnessed as a deactivation" do
    target = users(:redella)

    assert_difference -> { role_entries.where(:action => "user_deactivate").count }, 1 do
      assert_empty target.update_roles!(%w[redaktion alumni], :actor => users(:aaron))
    end

    assert target.reload.alumni?
    assert target.redaktion?, "deactivate! preserves the other roles"
  end

  test "revoking and granting in one submission apply in the right order" do
    target = users(:redella)
    target.update_column(:otp_secret, ROTP::Base32.random)

    assert_empty target.update_roles!(%w[admin], :actor => users(:aaron))

    assert_equal %w[admin], target.reload.roles
    actions = role_entries.order(:id).last(2).map(&:action)
    assert_includes actions, "redaktion_revoke"
    assert_includes actions, "admin_grant"
  end
  
protected
  def create_user(options = {})
    record = User.new({ :login => 'quire', :email => 'quire@example.com', :password => 'quire69', :password_confirmation => 'quire69' }.merge(options))
    record.save
    record
  end
end
