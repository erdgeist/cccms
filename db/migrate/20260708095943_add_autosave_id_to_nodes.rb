class AddAutosaveIdToNodes < ActiveRecord::Migration[8.1]
  def change
    add_column :nodes, :autosave_id, :integer
  end
end
