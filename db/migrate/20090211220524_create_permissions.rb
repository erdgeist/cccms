class CreatePermissions < ActiveRecord::Migration[4.2]
  def self.up
    create_table :permissions do |t|
      t.boolean :granted
      t.integer :node_id
      t.integer :user_id
      
      t.timestamps
    end
  end

  def self.down
    drop_table :permissions
  end
end
