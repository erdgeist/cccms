class AddRolesToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :roles, :string, :array => true, :default => [], :null => false
    execute "UPDATE users SET roles = ARRAY['admin','redaktion'] WHERE admin = true"
    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean
    execute "UPDATE users SET admin = true WHERE 'admin' = ANY(roles)"
    remove_column :users, :roles
  end
end
