namespace :node_actions do
  desc "Rebuild inferred NodeAction entries from existing revisions and " \
       "node timestamps. Witnessed entries (inferred_from IS NULL) are " \
       "never touched; previously inferred ones are deleted and " \
       "regenerated, so the task is idempotent. Scope with NODE_ID=n."
  task :backfill => :environment do
    scope = Node.where.not(:parent_id => nil)
    scope = scope.where(:id => ENV["NODE_ID"]) if ENV["NODE_ID"]

    created = 0

    ActiveRecord::Base.transaction do
      stale = NodeAction.where.not(:inferred_from => nil)
      stale = stale.where(:node_id => ENV["NODE_ID"]) if ENV["NODE_ID"]
      puts "Removing #{stale.count} previously inferred entries"
      stale.delete_all

      witnessed_creates  = NodeAction.where(:action => "create",  :inferred_from => nil).pluck(:node_id).to_set
      witnessed_promotes = NodeAction.where(:action => "publish", :inferred_from => nil).pluck(:page_id).to_set

      scope.find_each do |node|
        # Every page row except the current draft was once promoted to
        # head. Autosaves never carry node_id, so they cannot appear.
        revisions  = node.pages.to_a.reject { |page| page.id == node.draft_id }
        first_page = node.pages.first

        unless witnessed_creates.include?(node.id)
          NodeAction.record!(
            :node => node, :page => first_page, :user => first_page&.editor,
            :action        => "create",
            :occurred_at   => node.created_at,
            :inferred_from => "from_node_created_at",
            :title => first_page&.translations&.find_by(:locale => I18n.default_locale)&.title,
            :path  => node.unique_name,
            :human_readable_node_name =>
              first_page&.translations&.find_by(:locale => I18n.default_locale)&.title)
          created += 1
        end

        previous = nil
        revisions.each do |page|
          unless witnessed_promotes.include?(page.id)
            diff = NodeAction.head_diff(previous, page)
            NodeAction.record!(
              :node => node, :page => page, :user => page.editor,
              :action        => "publish",
              :occurred_at   => page.updated_at,
              :inferred_from => "from_page_revision",
              :via           => "draft",
              :human_readable_node_name => diff[:title]["to"],
              **diff)
            created += 1
          end
          previous = page
        end
      end
    end

    puts "Created #{created} inferred entries"
  end
end
