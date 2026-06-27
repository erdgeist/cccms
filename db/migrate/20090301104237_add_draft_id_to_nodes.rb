class AddDraftIdToNodes < ActiveRecord::Migration[4.2]
  def self.up
    add_column :nodes, :draft_id, :integer
  end

  def self.down
    remove_column :nodes, :draft_id
  end
end
