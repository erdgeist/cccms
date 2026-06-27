class AddUserIdToPages < ActiveRecord::Migration[4.2]
  def self.up
    add_column :pages, :user_id, :integer
  end

  def self.down
    add_column :pages, :user_id
  end
end
