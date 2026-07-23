class CreateActionParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :action_participants do |t|
      t.references :node_action, null: false, foreign_key: true, index: false
      t.references :subject, polymorphic: true, null: false, index: false
    end
    add_index :action_participants, [:subject_type, :subject_id, :node_action_id],
              :name => "index_action_participants_on_subject_and_action"
    add_index :action_participants, [:node_action_id, :subject_type, :subject_id],
              :unique => true,
              :name => "index_action_participants_uniqueness"
  end
end
