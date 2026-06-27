class UpgradeTaggingsForActsAsTaggableOn < ActiveRecord::Migration[4.2]
  def up
    add_column :taggings, :context,     :string
    add_column :taggings, :tagger_id,   :integer
    add_column :taggings, :tagger_type, :string

    # populate context for existing taggings
    execute "UPDATE taggings SET context = 'tags'"

    add_index :taggings, :context
    add_index :taggings, [:tagger_id, :tagger_type]
  end

  def down
    remove_column :taggings, :context
    remove_column :taggings, :tagger_id
    remove_column :taggings, :tagger_type
  end
end
