class CreateNodeActions < ActiveRecord::Migration[8.1]
  def change
    create_table :node_actions do |t|
      t.references :node, foreign_key: { on_delete: :nullify }
      t.references :page, foreign_key: { on_delete: :nullify }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string   :action, null: false
      t.string   :locale
      t.string   :inferred_from
      t.jsonb    :metadata, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :node_actions, [:node_id, :occurred_at]
    add_index :node_actions, :action
  end
end
