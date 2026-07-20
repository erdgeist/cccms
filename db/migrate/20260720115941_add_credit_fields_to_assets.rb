class AddCreditFieldsToAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :assets, :license_key, :string
    add_column :assets, :creator, :string
    add_column :assets, :source_url, :string
  end
end
