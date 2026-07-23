module NodeActionsHelper
  include ERB::Util

  # One glyph per verb, rendered before the sentence in _action_row.
  # Unknown verbs get the dashed circle -- the unknown-verb principle
  # extended to iconography: the log outlives its vocabulary.
  VERB_ICONS = {
    "create"             => "file-plus",
    "publish"            => "send",
    "move"               => "arrows-move",
    "trash"              => "trash",
    "restore_from_trash" => "arrow-back-up",
    "destroy"            => "trash-x",
    "discard_autosave"   => "eraser",
    "destroy_draft"      => "eraser",
    "asset_create"       => "upload",
    "asset_attach"       => "paperclip",
    "asset_destroy"      => "file-x"
  }.freeze

  def verb_icon action
    name = if action.action == "publish" && action.metadata["via"] == "revision"
      "history"
    else
      VERB_ICONS.fetch(action.action, "circle-dashed")
    end
    content_tag(:span, icon(name, library: "tabler", "aria-hidden": true),
                :class => "node_action_icon node_action_icon--#{name}",
                :title => action.action)
  end

  # One sentence per entry, rendered from metadata alone, so entries
  # stay renderable after the rows they reference are gone. Live
  # associations only upgrade plain names to links. Every metadata
  # value passes through h() here -- this helper is the escaping
  # boundary; the locale sentences are trusted, the data never is.
  def action_summary action
    renderer = "summarize_#{action.action}"
    return send(renderer, action) if respond_to?(renderer, true)

    # Unknown-verb fallback: the log outlives the vocabulary. A renamed
    # or future verb degrades to an ugly sentence, never to a 500.
    t("node_actions.unknown", :actor => actor_ref(action),
       :action => h(action.action), :subject => subject_ref(action)).html_safe
  end


  def action_details? action
    m = action.metadata
    return true if m["translation_diff"].present?
    return true if m["title"].is_a?(Hash) && m.dig("title", "from") != m.dig("title", "to")
    %w[author tags template_changed assets assets_changed assets_reordered
       abstract_changed body_changed].any? { |key| m[key].present? }
  end

  # Plain strings by design -- safe_join in the template escapes them.
  def default_locale_changes action
    m = action.metadata
    items = []
    if m["title"].is_a?(Hash) && m.dig("title", "from") && m.dig("title", "from") != m.dig("title", "to")
      items << t("node_actions.detail_title",
                  :from => m.dig("title", "from"), :to => m.dig("title", "to"))
    end
    items << t("node_actions.detail_author",
                :from => m.dig("author", "from"), :to => m.dig("author", "to")) if m["author"]
    items << t("node_actions.detail_tags",
                :from => Array(m.dig("tags", "from")).join(", "),
                :to   => Array(m.dig("tags", "to")).join(", ")) if m["tags"]
    items << t("node_actions.abstract_changed") if m["abstract_changed"]
    items << t("node_actions.body_changed")     if m["body_changed"]
    items << t("node_actions.template_changed") if m["template_changed"]
    if m["assets"]
      items << t("node_actions.detail_assets_added",
                  :names => Array(m.dig("assets", "added")).join(", "))   if m.dig("assets", "added")
      items << t("node_actions.detail_assets_removed",
                  :names => Array(m.dig("assets", "removed")).join(", ")) if m.dig("assets", "removed")
    end
    items << t("node_actions.assets_reordered") if m["assets_reordered"]
    items << t("node_actions.assets_changed")   if m["assets_changed"]
    items
  end

  def translation_changes diff
    case diff["status"]
    when "added"   then [t("node_actions.locale_added",   :title => diff.dig("title", "to"))]
    when "removed" then [t("node_actions.locale_removed", :title => diff.dig("title", "from"))]
    else
      items = []
      items << t("node_actions.detail_title",
                  :from => diff.dig("title", "from"), :to => diff.dig("title", "to")) if diff["title"]
      items << t("node_actions.abstract_changed") if diff["abstract_changed"]
      items << t("node_actions.body_changed")     if diff["body_changed"]
      items
    end
  end

  def revision_lifecycle_badges actions
    return "" if actions.blank?

    badges = actions.map do |action|
      key = case action.action
            when "create"  then "node_actions.revision_created"
            when "publish" then action.metadata["via"] == "revision" ?
                                  "node_actions.revision_restored" :
                                  "node_actions.revision_published"
            end
      next unless key

      badge = h(t(key, :date => action.occurred_at.strftime("%Y-%m-%d"),
                       :actor => action.actor_name))
      if action.inferred_from
        badge = safe_join([badge, content_tag(:span, t("node_actions.backfilled"),
                                               :class => "node_action_inferred",
                                               :title => action.inferred_from)], " ")
      end
      badge
    end.compact

    return "" if badges.empty?
    safe_join(["— ", safe_join(badges, " · ")])
  end

  private

  def revision_ref action, key
    label = t(key)
    return label unless action.node && action.page
    link_to(label, node_revision_path(action.node, action.page))
  end

  def actor_ref action
    action.user ? link_to(h(action.actor_name), admin_log_path(:user_id => action.user_id))
                : h(action.actor_name)
  end

  def subject_ref action
    action.node ? link_to(h(action.subject_name), node_path(action.node))
                : h(action.subject_name)
  end

  def summarize_publish action
    if action.metadata["via"] == "revision"
      t("node_actions.publish_rollback",
         :actor => actor_ref(action), :subject => subject_ref(action),
         :revision => revision_ref(action, "node_actions.revision_earlier")).html_safe
    elsif action.metadata.dig("title", "from").nil?
      author = action.metadata.dig("author", "to")
      key = author ? "node_actions.publish_first_with_author" : "node_actions.publish_first"
      t(key, :actor => actor_ref(action), :subject => subject_ref(action),
              :author => h(author)).html_safe
    else
      t("node_actions.publish",
         :actor => actor_ref(action), :subject => subject_ref(action),
         :revision => revision_ref(action, "node_actions.revision_new")).html_safe
    end
  end

  def summarize_move action
    t("node_actions.move", :actor => actor_ref(action), :subject => subject_ref(action),
       :from => h(action.metadata.dig("path", "from")),
       :to   => h(action.metadata.dig("path", "to"))).html_safe
  end

  def summarize_create action
    t("node_actions.create", :actor => actor_ref(action), :subject => subject_ref(action),
       :path => h(action.metadata["path"])).html_safe
  end

  def summarize_discard_autosave action
    t("node_actions.discard_autosave",
       :actor => actor_ref(action), :subject => subject_ref(action)).html_safe
  end

  def summarize_destroy_draft action
    t("node_actions.destroy_draft",
       :actor => actor_ref(action), :subject => subject_ref(action)).html_safe
  end

  def summarize_trash action
    t("node_actions.trash", :actor => actor_ref(action), :subject => subject_ref(action),
       :from => h(action.metadata.dig("path", "from"))).html_safe
  end

  def summarize_restore_from_trash action
    t("node_actions.restore_from_trash", :actor => actor_ref(action), :subject => subject_ref(action),
       :to => h(action.metadata.dig("path", "to"))).html_safe
  end

  def summarize_destroy action
    t("node_actions.destroy", :actor => actor_ref(action), :subject => subject_ref(action),
       :path => h(action.metadata["path"])).html_safe
  end

  def summarize_asset_create action
    t("node_actions.asset_create", :actor => actor_ref(action),
       :asset => h(action.metadata["asset_name"].presence || action.metadata["path"])).html_safe
  end

  def summarize_asset_attach action
    m = action.metadata
    key = m["headline"] ? "node_actions.asset_attach_headline" : "node_actions.asset_attach"
    t(key, :actor => actor_ref(action), :subject => subject_ref(action),
       :asset => h(m["asset_name"].presence || m["path"])).html_safe
  end

  def summarize_asset_destroy action
    m = action.metadata
    parts = [t("node_actions.asset_destroy", :actor => actor_ref(action),
                :asset => h(m["asset_name"].presence || m["path"]))]
    parts << t("node_actions.asset_destroy_detached",
                :paths => h(Array(m["detached_from"]).join(", "))) if m["detached_from"].present?
    parts << t("node_actions.asset_destroy_headlines",
                :paths => h(Array(m["headline_removed_from"]).join(", "))) if m["headline_removed_from"].present?
    safe_join(parts, " ")
  end
end
