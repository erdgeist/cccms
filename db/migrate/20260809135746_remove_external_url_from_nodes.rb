class RemoveExternalUrlFromNodes < ActiveRecord::Migration[8.1]
  def change
    remove_column :nodes, :external_url, :string
  end
end
