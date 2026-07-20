class AddHeadlineToRelatedAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :related_assets, :headline, :boolean, null: false, default: false
    add_index :related_assets, :page_id, unique: true, where: "headline = true",
               name: "index_related_assets_on_page_id_headline_uniqueness"
  end
end
