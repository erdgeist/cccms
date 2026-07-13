class AddPreviewTokenToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :preview_token, :string
    add_index :pages, :preview_token, unique: true
  end
end
