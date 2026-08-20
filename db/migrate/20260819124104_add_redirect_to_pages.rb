class AddRedirectToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :redirect, :string
    add_column :pages, :redirect_node_id, :integer
  end
end
