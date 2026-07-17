class DropNestedSetColumnsFromNodes < ActiveRecord::Migration[8.1]
  def change
    remove_column :nodes, :lft, :integer
    remove_column :nodes, :rgt, :integer
  end
end
