class AddAddressToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :slug, :string
    add_column :pages, :parent_node_id, :integer
  end
end
