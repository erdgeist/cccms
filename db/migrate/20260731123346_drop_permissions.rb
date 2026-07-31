class DropPermissions < ActiveRecord::Migration[8.1]
  def up
    drop_table :permissions
  end

  # Reversible for form's sake -- the table was empty and every write path
  # in the model was broken, so there is nothing to restore.
  def down
    create_table :permissions, :id => :serial do |t|
      t.boolean  :granted
      t.integer  :node_id
      t.integer  :user_id
      t.datetime :created_at, :precision => nil
      t.datetime :updated_at, :precision => nil
    end
  end
end
