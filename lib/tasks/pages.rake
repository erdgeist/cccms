namespace :pages do
  desc "Backfill pages.slug and pages.parent_node_id from each page's " \
       "node. Historical accuracy is not attempted. Every revision gets " \
       "the node's current address, which is right for head and draft and " \
       "harmless for older revisions, and avoids nil checks everywhere. " \
       "Dry run unless WRITE=1."
  task :backfill_address => :environment do
    write = ENV["WRITE"] == "1"
    puts "DRY RUN -- nothing written. Re-run with WRITE=1." unless write

    touched = 0
    Node.find_each do |node|
      scope = node.pages.where("slug IS DISTINCT FROM :s OR parent_node_id IS DISTINCT FROM :p",
                               :s => node.slug, :p => node.parent_id)
      count = scope.count
      next if count.zero?

      scope.update_all(:slug => node.slug, :parent_node_id => node.parent_id) if write
      touched += count
    end

    # Autosaves carry no node_id -- has_many :pages does not cover them.
    Node.where.not(:autosave_id => nil).includes(:autosave).find_each do |node|
      a = node.autosave
      next if a.slug == node.slug && a.parent_node_id == node.parent_id

      a.update_columns(:slug => node.slug, :parent_node_id => node.parent_id) if write
      touched += 1
    end

    puts "#{write ? "updated" : "would update"} #{touched} pages"
  end

  desc "Backfill pages.external_url from each page's node."
  task :backfill_external_url => :environment do
    write = ENV["WRITE"] == "1"
    puts "DRY RUN -- nothing written. Re-run with WRITE=1." unless write

    touched = 0
    Node.where.not(:external_url => [nil, ""]).find_each do |node|
      scope = node.pages.where("external_url IS DISTINCT FROM :u", :u => node.external_url)
      count = scope.count
      next if count.zero?

      scope.update_all(:external_url => node.external_url) if write
      touched += count
    end

    # Autosaves carry no node_id, so has_many :pages does not cover them.
    Node.where.not(:autosave_id => nil).where.not(:external_url => [nil, ""])
        .includes(:autosave).find_each do |node|
      a = node.autosave
      next if a.nil? || a.external_url == node.external_url

      a.update_columns(:external_url => node.external_url) if write
      touched += 1
    end

    puts "#{write ? "updated" : "would update"} #{touched} pages"
  end
end
