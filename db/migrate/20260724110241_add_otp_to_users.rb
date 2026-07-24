class AddOtpToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_secret, :string
    add_column :users, :otp_pending_secret, :string
    add_column :users, :otp_consumed_timestep, :integer
    add_column :users, :otp_required, :boolean, :null => false, :default => false
  end
end
