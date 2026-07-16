class NodeAction < ApplicationRecord
  belongs_to :node, optional: true
  belongs_to :page, optional: true
  belongs_to :user, optional: true

  validates :action, presence: true
  validates :occurred_at, presence: true

  # == Metadata contract ==
  #
  # metadata is written once at creation and never updated. It is the
  # single place anything that must survive deletion of the referenced
  # rows lives; node_id/page_id/user_id are lookup and ordering only.
  # All keys are strings. Pairs are always {"from" => x, "to" => y} --
  # never _old/_new suffixes. Optional pairs are written only when the
  # two sides differ; required keys are always present. All titles and
  # names are read pinned to I18n.default_locale unless inside a
  # locale-keyed block.
  #
  # Baseline, every entry (written here, not by call sites):
  #   "username"                 -- actor's login at write time
  #   "human_readable_node_name" -- node title, default locale
  #
  # "create":
  #   "title" -- initial title, default locale
  #   "path"  -- unique path at creation time. Historical value only:
  #              later renames/moves do NOT update old entries. Never
  #              use as a join key; node_id is the join key while the
  #              node lives.
  #
  # "publish" (any promotion of a page to head; the diff against the
  # outgoing head is computed BEFORE head is re-pointed, over the
  # union of both pages' locales, by the shared diff function also
  # used by the backfill):
  #   "via"    -- "draft" (ordinary publish) | "revision" (rollback
  #               via restore_revision!). Always written; absent
  #               means a pre-contract entry.
  #   "title"  -- pair, always present. "from" is null on a first
  #               publish (no outgoing head).
  #   "author" -- pair, only when the byline (page.user) changed
  #   "tags"   -- pair of arrays, only when changed
  #   "assets_changed", "template_changed"
  #            -- booleans, only when true; page_id links to the
  #               revision for the real diff (never stored here)
  #   "abstract_changed", "body_changed"
  #            -- booleans for the default locale, only when true
  #   "translation_diff" -- only when any non-default locale differs:
  #     { "<locale>" => {
  #         "status"           -- "added" | "removed" | "changed"
  #         "title"            -- pair; "from" null when added,
  #                               "to" null when removed
  #         "abstract_changed", "body_changed" -- booleans, only when
  #                               true, only for status "changed"
  #     } }
  #
  # "move" (reparenting and/or unique-path change; one entry at the
  # subtree root, descendants get none -- a descendant's own zoomed
  # view will not show path history):
  #   "path"  -- pair
  #
  # Reserved for the Trash feature, final shape decided there:
  # "demote" (via "trash" | "depublish"; carries the leaving-public-
  # view snapshot: head presence, final published_at), "trash",
  # "restore_from_trash", "destroy" (final path only; publish-state
  # snapshot lives on the entry that removed it from public view).
  # Whether trash logs one entry or a trash+demote pair is decided
  # with that feature.
  #
  # Backfilled entries mirror this vocabulary exactly. Their diff
  # content is computed, not guessed (consecutive revisions still
  # exist); only actor (from page.editor) and occurred_at are
  # inferred, and inferred_from names the heuristic per entry
  # ("from_page_revision", "from_published_at_heuristic").
  # inferred_from null = witnessed live.
  #
  # The "locale" column is currently written by no verb (it belonged
  # to the retired translation_destroy) and is retained for backfill
  # or future draft-scoped verbs.
  #
  # This log records; it does not undo. Reversibility stays in
  # restore_revision! and the revisions system. No IP, session, or
  # user agent, ever. Success only -- rejected attempts are not
  # logged.

  def self.record!(node:, action:, user: nil, page: nil, locale: nil, **extra)
    create!(
      :node        => node,
      :page        => page,
      :user        => user,
      :action      => action,
      :locale      => locale,
      :occurred_at => Time.now,
      :metadata    => {
        "username"                 => user&.login,
        "human_readable_node_name" => Globalize.with_locale(I18n.default_locale) {
                                        node&.head&.title || node&.draft&.title
                                      },
      }.merge(extra.stringify_keys)
   )
  end

  # Computes the publish-entry diff between an outgoing head and the
  # page replacing it, in the exact metadata shape the contract above
  # specifies. Pure function of its two arguments -- shared verbatim by
  # publish_draft!, restore_revision!, and the backfill task. Reads
  # translation rows directly, never locale-dependent accessors, so a
  # fallback value is never mistaken for real content. Returns
  # symbol-keyed top level for splatting into record!; nested keys are
  # strings and jsonb serialization stringifies the rest at write time.
  def self.head_diff old_page, new_page
    default = I18n.default_locale

    title_of = ->(page) { page&.translations&.find_by(:locale => default)&.title }
    diff = { :title => { "from" => title_of.call(old_page),
                         "to"   => title_of.call(new_page) } }
    return diff unless old_page

    old_author, new_author = old_page.user&.login, new_page.user&.login
    diff[:author] = { "from" => old_author, "to" => new_author } if old_author != new_author

    old_tags, new_tags = old_page.tag_list.sort, new_page.tag_list.sort
    diff[:tags] = { "from" => old_tags, "to" => new_tags } if old_tags != new_tags

    diff[:template_changed] = true if old_page.template_name != new_page.template_name
    diff[:assets_changed]   = true if old_page.assets.map(&:id) != new_page.assets.map(&:id)

    old_t = old_page.translations.find_by(:locale => default)
    new_t = new_page.translations.find_by(:locale => default)
    diff[:abstract_changed] = true if old_t&.abstract != new_t&.abstract
    diff[:body_changed]     = true if old_t&.body != new_t&.body

    locales = (old_page.translated_locales | new_page.translated_locales) - [default]
    translation_diff = {}

    locales.sort_by(&:to_s).each do |locale|
      o = old_page.translations.find_by(:locale => locale)
      n = new_page.translations.find_by(:locale => locale)

      if o.nil?
        translation_diff[locale.to_s] = { "status" => "added",
                                          "title" => { "from" => nil, "to" => n.title } }
      elsif n.nil?
        translation_diff[locale.to_s] = { "status" => "removed",
                                          "title" => { "from" => o.title, "to" => nil } }
      elsif o.title != n.title || o.abstract != n.abstract || o.body != n.body
        entry = { "status" => "changed" }
        entry["title"]            = { "from" => o.title, "to" => n.title } if o.title != n.title
        entry["abstract_changed"] = true if o.abstract != n.abstract
        entry["body_changed"]     = true if o.body != n.body
        translation_diff[locale.to_s] = entry
      end
    end

    diff[:translation_diff] = translation_diff if translation_diff.any?
    diff
  end

  def actor_name
    metadata["username"] || "unknown"
  end

  def subject_name
    metadata["human_readable_node_name"] || node&.unique_name || "deleted node"
  end
end
