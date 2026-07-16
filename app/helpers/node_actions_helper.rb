module NodeActionsHelper
  include ERB::Util

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

  private

  def actor_ref action
    action.user ? link_to(h(action.actor_name), admin_log_path(:user_id => action.user_id))
                : h(action.actor_name)
  end

  def subject_ref action
    action.node ? link_to(h(action.subject_name), node_path(action.node))
                : h(action.subject_name)
  end

  def summarize_publish action
    key = if action.metadata["via"] == "revision"
            "node_actions.publish_rollback"
          elsif action.metadata.dig("title", "from").nil?
            "node_actions.publish_first"
          else
            "node_actions.publish"
          end

    t(key, :actor => actor_ref(action), :subject => subject_ref(action),
            :from => h(action.metadata.dig("title", "from")),
            :to   => h(action.metadata.dig("title", "to"))).html_safe
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
end
