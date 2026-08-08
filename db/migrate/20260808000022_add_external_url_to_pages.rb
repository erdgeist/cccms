class AddExternalUrlToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :external_url, :string
  end
end
