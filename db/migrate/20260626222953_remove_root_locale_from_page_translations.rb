class RemoveRootLocaleFromPageTranslations < ActiveRecord::Migration[7.2]
  def up
    count = execute("DELETE FROM page_translations WHERE locale = 'root'").cmd_tuples
    say "Deleted #{count} root locale records from page_translations"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
