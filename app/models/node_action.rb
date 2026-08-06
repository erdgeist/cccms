class NodeAction < ApplicationRecord
  belongs_to :node, optional: true
  belongs_to :page, optional: true
  belongs_to :user, optional: true

  has_many :action_participants, -> { order(:id) }, :dependent => :destroy

  validates :action, presence: true
  validates :occurred_at, presence: true

  # == Metadata contract ==
  #
  # metadata is written once at creation, never updated. It is the
  # single place anything that must survive deletion of the referenced
  # rows lives; node_id/page_id/user_id are lookup and ordering only.
  # All keys are strings. Pairs are always {"from" => x, "to" => y}.
  # Optional pairs only when the sides differ; booleans only when
  # true; required keys always present. Titles and names are read
  # pinned to I18n.default_locale unless inside a locale-keyed block.
  #
  # Baseline, every entry (written here, not by call sites):
  #   "username"                 -- actor's login at write time
  #   "human_readable_node_name" -- node title, default locale
  #
  # "create":
  #   "title" -- initial title, flat string (NOT a pair)
  #   "path"  -- unique path at creation, flat string. Historical
  #              value only; never a join key.
  #
  # "publish" (any promotion to head; diff computed BEFORE head is
  # re-pointed, over the union of both pages' locales, by head_diff --
  # shared with the backfill):
  #   "via"    -- "draft" | "revision" (rollback). Always written;
  #               absent means a pre-contract entry.
  #   "title"  -- pair, always; "from" null on first publish
  #   "author" -- pair, when the byline changed (incl. first publish)
  #   "tags"   -- pair of arrays, when changed
  #   "assets" -- {"added" => [asset names], "removed" => [asset names]},
  #               keys only when any; a delta, not a pair. The event IS
  #               the delta, full sets would bloat every entry. Changed
  #               assets are participants of the entry. Replaces the
  #               legacy "assets_changed" boolean, which witnessed
  #               pre-contract entries still carry and the renderer keeps
  #               understanding. Assets destroyed since leave no trace in
  #               regenerated deltas, their joins died with them.
  #   "assets_reordered" -- boolean, set unchanged but gallery order not
  #   "template_changed", "abstract_changed", "body_changed"
  #            -- the last two for the default locale; page_id links
  #               to the revision for the real diff (never stored)
  #   "translation_diff" -- only when a non-default locale differs:
  #     { "<locale>" => {
  #         "status" -- "added" | "removed" | "changed"
  #         "title"  -- pair, only when it differs; "from" null when
  #                     added, "to" null when removed
  #         "abstract_changed", "body_changed" -- status "changed" only
  #     } }
  #
  # "move" (reparent and/or path change; one entry at the subtree
  # root, descendants get none):
  #   "path" -- pair
  #
  # "trash" (subtree into the Trash; every head in the subtree is
  # demoted first; one entry at the root; snapshots the
  # leaving-public-view state, since Trash holds no heads and destroy
  # can no longer know):
  #   "path"               -- pair; "from" doubles as the restore hint
  #   "was_published"      -- boolean
  #   "demoted_heads"      -- integer count, only when positive
  #   "final_published_at" -- ISO8601 string, only when present
  #
  # "restore_from_trash" (reparent back to a living node; returns as
  # drafts, republication is a separate witnessed act):
  #   "path" -- pair
  #
  # "destroy" (only from inside the Trash, never with children; the
  # entry is written in the same transaction before the row dies):
  #   "path" -- final path, flat string (create-symmetric)
  #   "destroyed_descendants" -- integer, only when positive; one entry
  #                              at the root, per the subtree rule.
  #
  # "asset_create" (witnessed upload; participants: the asset alone):
  #   "asset_name", "content_type", "path" -- flat strings
  #
  # "asset_attach" (out-of-band attach via Node#attach_asset!; written
  # only when at least one new join was created, per the tandem rule --
  # in-editor curation stays draft-scoped and surfaces at publish.
  # participants: the node (primary) and the asset):
  #   "asset_name", "path" -- flat strings
  #   "headline"           -- boolean, only when set by this attach
  #
  # "asset_destroy" (witnessed asset deletion; always written, even for
  # unattached assets -- the files were publicly reachable; node column
  # nil, subjects via participants: the asset plus every then-attached
  # node):
  #   "asset_name"            -- flat string
  #   "content_type"          -- flat string
  #   "path"                  -- public original path, flat string
  #   "detached_from"         -- array of unique_names, only when any
  #   "headline_removed_from" -- array of unique_names, only when any
  #
  # "otp_enroll" / "otp_disable" / "otp_reset" (second-factor
  # lifecycle) and "user_create" / "user_deactivate" /
  # "user_reactivate" (account lifecycle). Node column nil;
  # participants: the affected User, a User-typed subject.
  # otp_disable is self-service; otp_reset and all three account
  # verbs are an administrator acting on someone else, so actor and
  # participant differ:
  #   "redaktion_grant" / "redaktion_revoke" / "admin_grant" /
  #   "admin_revoke" -- role changes. Both pairs come from
  #   User#grant_* / #revoke_*, so the roles form reaches them through
  #   update_roles! rather than writing the attribute: witnessing is the
  #   reason the form does not touch roles directly. Alumni changes record
  #   as user_deactivate / user_reactivate, not as a role verb.
  #   "target_login" -- flat string, the affected account's login
  #
  # "event_create" / "event_update" / "event_destroy" (calendar
  # entries; participants: the Event and, when it has one, its Node,
  # which also fills the node column. Deliberately not gated --
  # events reach chapter pages and widgets, never the feeds, and
  # protection here follows emission, not position).
  #
  # Events carry no revisions, so the log is their only history:
  # every entry holds a full snapshot of the state it produced, and
  # walking an event's entries reconstructs it. Times are ISO 8601
  # and the rrule is raw, never humanised -- entries are read in both
  # locales and event_schedule_text resolves that at render time.
  #   "event_title" -- flat string; the title, else the node's
  #                    unique_name, else "#<id>"
  #   "start_time", "end_time" -- ISO 8601, when set
  #   "allday"      -- boolean
  #   "rrule"       -- raw RRULE, when set
  #   "location", "url" -- flat strings, when set
  #   "event_tags"  -- array of names, sorted, always. Named apart
  #                    from the node verbs' "tags", which is a pair,
  #                    so one renderer cannot mistake the other.
  #   "path"        -- the node's unique_name, when it has a node
  #   "external_url" -- pair
  #
  # On "event_update" only, and only when something changed -- an
  # update that changes nothing records no entry at all:
  #   "changes"     -- {field => pair}, node_id resolved to paths
  #                    under "node_path", tag_list under "tags",
  #                    times as ISO 8601
  #   "description_changed" -- boolean; prose, flagged not quoted,
  #                    as abstract_changed and body_changed are
  #
  # Reserved: "demote" (via "trash" | "depublish") for an explicit
  # depublish workflow, if ever built.
  #
  # Backfilled entries mirror this vocabulary; diff content is
  # computed, only actor (page.editor) and occurred_at are inferred,
  # inferred_from names the heuristic ("from_node_created_at",
  # "from_page_revision"). Null = witnessed live.
  #
  # The "locale" column is written by no verb; retained.
  #
  # This log records; it does not undo. No IP, session, or user
  # agent, ever. Success only.

  def self.record!(node: nil, participants: [], action:, user: nil, page: nil,
                    locale: nil, occurred_at: nil, inferred_from: nil, **extra)
    participants = participants.presence || [node].compact
    raise ArgumentError, "NodeAction.record! needs at least one participant" if participants.empty?

    primary_node = node || (participants.first if participants.first.is_a?(Node))

    create!(
      :node          => primary_node,
      :page          => page,
      :user          => user,
      :action        => action,
      :locale        => locale,
      :occurred_at   => occurred_at || Time.now,
      :inferred_from => inferred_from,
      :metadata      => {
        "username"                 => user&.login,
        "human_readable_node_name" => Globalize.with_locale(I18n.default_locale) {
                                        primary_node&.head&.title || primary_node&.draft&.title
                                      },
      }.merge(extra.stringify_keys)
    ).tap do |na|
      participants.each { |subject| na.action_participants.create!(:subject => subject) }
    end
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
    unless old_page
      diff[:author] = { "from" => nil, "to" => new_page.user&.login } if new_page.user
      return diff
    end

    old_author, new_author = old_page.user&.login, new_page.user&.login
    diff[:author] = { "from" => old_author, "to" => new_author } if old_author != new_author

    old_tags, new_tags = old_page.tag_list.sort, new_page.tag_list.sort
    diff[:tags] = { "from" => old_tags, "to" => new_tags } if old_tags != new_tags

    diff[:template_changed] = true if old_page.template_name != new_page.template_name

    old_assets, new_assets = old_page.assets.to_a, new_page.assets.to_a
    added, removed = new_assets - old_assets, old_assets - new_assets
    if added.any? || removed.any?
      assets = {}
      assets["added"]   = added.map   { |a| a.name.presence || a.upload_file_name } if added.any?
      assets["removed"] = removed.map { |a| a.name.presence || a.upload_file_name } if removed.any?
      diff[:assets] = assets
    elsif old_assets.map(&:id) != new_assets.map(&:id)
      diff[:assets_reordered] = true
    end

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

  # The asset records added or removed between an outgoing head and its
  # replacement -- the participant complement to head_diff's "assets"
  # names. Empty on first publish, mirroring head_diff, which records
  # no asset delta when everything is new.
  def self.changed_assets old_page, new_page
    return [] unless old_page
    old_a, new_a = old_page.assets.to_a, new_page.assets.to_a
    (new_a - old_a) | (old_a - new_a)
  end

  def actor_name
    metadata["username"] || "unknown"
  end

  def subject_name
    metadata["human_readable_node_name"] || node&.unique_name || "deleted node"
  end

  def diff_link_params
    prev = NodeAction.where(node_id: node_id, action: "publish")
                     .where("id < ?", id)
                     .order(id: :desc).first
    return nil unless prev&.page && page
    { start_revision: prev.page.revision, end_revision: page.revision }
  end
end
