class AddSearchVectorToPageTranslations < ActiveRecord::Migration[7.2]
  def up
    add_column :page_translations, :search_vector, :tsvector

    execute <<~SQL
      UPDATE page_translations
      SET search_vector = to_tsvector(
        'simple',
        coalesce(title, '') || ' ' ||
        coalesce(abstract, '') || ' ' ||
        coalesce(body, '')
      )
    SQL

    add_index :page_translations, :search_vector,
              using: :gin,
              name: 'index_page_translations_on_search_vector'

    execute <<~SQL
      CREATE OR REPLACE FUNCTION page_translations_search_vector_update()
      RETURNS trigger AS $$
      BEGIN
        NEW.search_vector := to_tsvector(
          'simple',
          coalesce(NEW.title, '') || ' ' ||
          coalesce(NEW.abstract, '') || ' ' ||
          coalesce(NEW.body, '')
        );
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER page_translations_search_vector_trigger
      BEFORE INSERT OR UPDATE ON page_translations
      FOR EACH ROW EXECUTE PROCEDURE page_translations_search_vector_update();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS page_translations_search_vector_trigger ON page_translations;
      DROP FUNCTION IF EXISTS page_translations_search_vector_update();
    SQL
    remove_index :page_translations, name: 'index_page_translations_on_search_vector'
    remove_column :page_translations, :search_vector
  end
end
