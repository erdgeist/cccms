class AddHeadIdToNode < ActiveRecord::Migration[4.2]
  def self.up
    add_column :nodes, :head_id, :integer
  end

  def self.down
    remove_column :nodes, :head_id
  end
end
