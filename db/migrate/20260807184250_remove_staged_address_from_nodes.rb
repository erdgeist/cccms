class RemoveStagedAddressFromNodes < ActiveRecord::Migration[8.1]
  def change
    remove_column :nodes, :staged_slug, :string
    remove_column :nodes, :staged_parent_id, :integer
  end
end
