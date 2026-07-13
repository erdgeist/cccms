Rails.application.config.after_initialize do
  begin
    Page.ensure_search_vector_trigger! if Page.connection.table_exists?(:page_translations)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad
    # Database doesn't exist yet -- e.g. mid `rails db:create`. Nothing to install yet.
  end
end
