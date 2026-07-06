class AddForeignKeyOnOccurrencesEventId < ActiveRecord::Migration[8.1]
  def change
    add_index :occurrences, :event_id
    add_foreign_key :occurrences, :events, on_delete: :cascade, deferrable: :immediate
  end
end
