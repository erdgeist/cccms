# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_19_124104) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_participants", force: :cascade do |t|
    t.bigint "node_action_id", null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.index ["node_action_id", "subject_type", "subject_id"], name: "index_action_participants_uniqueness", unique: true
    t.index ["subject_type", "subject_id", "node_action_id"], name: "index_action_participants_on_subject_and_action"
  end

  create_table "assets", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "creator"
    t.string "license_key"
    t.string "name", limit: 255
    t.string "source_url"
    t.datetime "updated_at", precision: nil
    t.string "upload_content_type", limit: 255
    t.string "upload_file_name", limit: 255
    t.integer "upload_file_size"
    t.datetime "upload_updated_at", precision: nil
  end

  create_table "events", id: :serial, force: :cascade do |t|
    t.boolean "allday"
    t.datetime "created_at", precision: nil
    t.text "description"
    t.datetime "end_time", precision: nil
    t.float "latitude"
    t.text "location"
    t.float "longitude"
    t.integer "node_id"
    t.string "rrule", limit: 255
    t.datetime "start_time", precision: nil
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.string "url", limit: 255
  end

  create_table "flags_pages", id: false, force: :cascade do |t|
    t.integer "flag_id"
    t.integer "page_id"
    t.index ["flag_id"], name: "index_flags_pages_on_flag_id"
    t.index ["page_id"], name: "index_flags_pages_on_page_id"
  end

  create_table "intern_mail_sent", id: false, force: :cascade do |t|
    t.integer "node_id"
  end

  create_table "menu_item_translations", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "locale", limit: 255
    t.integer "menu_item_id"
    t.string "title", limit: 255
    t.datetime "updated_at", precision: nil
  end

  create_table "menu_items", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "node_id"
    t.string "path", limit: 255
    t.integer "position"
    t.string "type", limit: 255
    t.integer "type_id"
    t.datetime "updated_at", precision: nil
  end

  create_table "node_actions", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.string "inferred_from"
    t.string "locale"
    t.jsonb "metadata", null: false
    t.bigint "node_id"
    t.datetime "occurred_at", null: false
    t.bigint "page_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["action"], name: "index_node_actions_on_action"
    t.index ["node_id", "occurred_at"], name: "index_node_actions_on_node_id_and_occurred_at"
    t.index ["node_id"], name: "index_node_actions_on_node_id"
    t.index ["page_id"], name: "index_node_actions_on_page_id"
    t.index ["user_id"], name: "index_node_actions_on_user_id"
  end

  create_table "nodes", id: :serial, force: :cascade do |t|
    t.integer "autosave_id"
    t.datetime "created_at", precision: nil
    t.string "default_template_name"
    t.integer "draft_id"
    t.integer "head_id"
    t.integer "locking_user_id"
    t.integer "parent_id"
    t.string "slug", limit: 255
    t.string "unique_name", limit: 255
    t.datetime "updated_at", precision: nil
    t.index ["draft_id"], name: "index_nodes_on_draft_id"
    t.index ["head_id"], name: "index_nodes_on_head_id"
    t.index ["id"], name: "index_nodes_on_id"
    t.index ["locking_user_id"], name: "index_nodes_on_locking_user_id"
    t.index ["parent_id"], name: "index_nodes_on_parent_id"
    t.index ["slug"], name: "index_nodes_on_slug"
    t.index ["unique_name"], name: "index_nodes_on_unique_name"
  end

  create_table "occurrences", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "end_time", precision: nil
    t.integer "event_id"
    t.integer "node_id"
    t.datetime "start_time", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["event_id"], name: "index_occurrences_on_event_id"
  end

  create_table "page_translations", id: :serial, force: :cascade do |t|
    t.text "abstract"
    t.text "body"
    t.datetime "created_at", precision: nil
    t.string "locale", limit: 255
    t.integer "page_id"
    t.tsvector "search_vector"
    t.string "title", limit: 255
    t.datetime "updated_at", precision: nil
    t.index ["locale"], name: "index_page_translations_on_locale"
    t.index ["page_id"], name: "index_page_translations_on_page_id"
    t.index ["search_vector"], name: "index_page_translations_on_search_vector", using: :gin
  end

  create_table "pages", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "editor_id"
    t.string "external_url"
    t.integer "node_id"
    t.integer "parent_node_id"
    t.string "preview_token"
    t.datetime "published_at", precision: nil
    t.string "redirect"
    t.integer "redirect_node_id"
    t.integer "revision"
    t.string "slug"
    t.string "template_name", limit: 255
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["id"], name: "index_pages_on_id"
    t.index ["node_id"], name: "index_pages_on_node_id"
    t.index ["preview_token"], name: "index_pages_on_preview_token", unique: true
    t.index ["revision"], name: "index_pages_on_revision"
    t.index ["user_id"], name: "index_pages_on_user_id"
  end

  create_table "related_assets", id: :serial, force: :cascade do |t|
    t.integer "asset_id"
    t.datetime "created_at", precision: nil
    t.boolean "headline", default: false, null: false
    t.integer "page_id"
    t.integer "position", default: 1
    t.datetime "updated_at", precision: nil
    t.index ["page_id"], name: "index_related_assets_on_page_id_headline_uniqueness", unique: true, where: "(headline = true)"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.string "context", limit: 255
    t.datetime "created_at", precision: nil
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string "taggable_type", limit: 255
    t.integer "tagger_id"
    t.string "tagger_type", limit: 255
    t.integer "user_id"
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id", "taggable_type"], name: "index_taggings_on_taggable_id_and_taggable_type"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["user_id", "tag_id", "taggable_type"], name: "index_taggings_on_user_id_and_tag_id_and_taggable_type"
    t.index ["user_id", "taggable_id", "taggable_type"], name: "index_taggings_on_user_id_and_taggable_id_and_taggable_type"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "taggings_count", default: 0, null: false
    t.index ["name"], name: "index_tags_on_name"
    t.index ["taggings_count"], name: "index_tags_on_taggings_count"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "crypted_password", limit: 255
    t.string "email", limit: 255
    t.datetime "last_login_at"
    t.string "login", limit: 255
    t.integer "otp_consumed_timestep"
    t.string "otp_pending_secret"
    t.boolean "otp_required", default: false, null: false
    t.string "otp_secret"
    t.string "password_digest"
    t.string "roles", default: [], null: false, array: true
    t.string "salt", limit: 255
    t.datetime "updated_at", precision: nil
  end

  add_foreign_key "action_participants", "node_actions"
  add_foreign_key "node_actions", "nodes", on_delete: :nullify
  add_foreign_key "node_actions", "pages", on_delete: :nullify
  add_foreign_key "node_actions", "users", on_delete: :nullify
  add_foreign_key "occurrences", "events", on_delete: :cascade, deferrable: :immediate
end
