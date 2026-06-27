class AddTypeColumnToMenuItems < ActiveRecord::Migration[4.2]
  def self.up
    add_column :menu_items, :type, :string
  end

  def self.down
    remove_column :menu_items, :type
  end
end
