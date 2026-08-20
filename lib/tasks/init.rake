namespace :cccms do
  desc "Bootstrap a fresh installation: the node skeleton and one admin " \
       "account. Idempotent -- every step finds before it creates, so " \
       "re-running after a new step is added is safe. " \
       "Requires ADMIN_PASS. ADMIN_LOGIN and ADMIN_EMAIL are optional. " \
       "The admin is created without the role and promoted with " \
       "update_column, because admin_needs_second_factor refuses a NEW " \
       "admin without an enrolled factor -- it exempts retention, not " \
       "creation. The account therefore cannot do user management until " \
       "it enrols a second factor and signs in again; see INSTALL.md."
  task :init => :environment do
    password = ENV["ADMIN_PASS"].to_s
    abort "usage: ADMIN_PASS=secret bundle exec rake cccms:init" if password.empty?
    abort "ADMIN_PASS must be at least 6 characters" if password.length < 6

    login = ENV.fetch("ADMIN_LOGIN", "admin")
    email = ENV.fetch("ADMIN_EMAIL", "admin@example.org")

    # publish_draft! is called with no user, which guard_live_change! treats
    # as a trusted system context -- the documented nil-user path, and the
    # reason a rake task can publish into /updates and /disclosure at all.
    ensure_node = lambda do |parent, slug, title, body|
      existing = parent ? parent.children.find_by(:slug => slug) : Node.root
      if existing
        puts format("  %-14s exists   (%d)", slug || "root", existing.id)
        next existing
      end

      node = parent ? parent.children.create!(:slug => slug) : Node.create!
      if parent.nil?
        node.reload
        node.update_column(:draft_id, node.pages.first.id) if node.draft_id.nil?
      end
      Globalize.with_locale(I18n.default_locale) do
        node.draft.update!(:title => title, :body => body.to_s)
      end
      node.publish_draft! if parent
      puts format("  %-14s created  (%d)", slug || "root", node.id)
      node
    end

    puts "Node skeleton:"
    root = ensure_node.(nil, nil, "CCC", "")

    # Referencing it is enough: Node.trash self-creates on first call.
    puts format("  %-14s ready    (%d)", "trash", Node.trash.id)

    ensure_node.(root, "home", "Startseite", "")

    ensure_node.(root, "updates", "Updates",
      '[aggregate tags="update" limit="30" order_by="published_at" order_direction="DESC"]')

    ensure_node.(root, "disclosure", "Disclosure", "")
    ensure_node.(root, "banner", "Banner", "")

    club = ensure_node.(root, "club", "Chaos Computer Club", "")
    ensure_node.(club, "erfas", "Erfa-Kreise",
      '[aggregate children="direct" order_by="slug" partial="chapter"]')
    ensure_node.(club, "chaostreffs", "Chaostreffs",
      '[aggregate children="direct" order_by="slug" partial="chapter"]')

    puts
    if User.any?
      puts "Accounts exist already; skipping admin creation."
    else
      user = User.create!(:login => login, :email => email,
                          :password => password,
                          :password_confirmation => password)
      user.update_column(:roles, %w[admin redaktion])
      puts "Created #{user.login} <#{user.email}> as admin + redaktion."
      puts
      puts "This account has no second factor, so it cannot yet create"
      puts "users, reset factors or deactivate accounts. To finish:"
      puts "  1. sign in as #{user.login}"
      puts "  2. Mein Konto -> enable second factor, scan the QR, confirm"
      puts "  3. sign out and sign in again, entering the code"
      puts "Elevation is granted at that login and user management unlocks."
    end
  end
end

namespace :pages do
  desc "Populate search_vector for rows that have none. The trigger " \
       "maintains it from then on, but fires only on insert or update, " \
       "so rows that predate it -- a restore from a dump taken before " \
       "the trigger existed, or a seed run against a database whose " \
       "trigger had been dropped -- stay unsearchable until this runs."
  task :backfill_search_vector => :environment do
    Page.ensure_search_vector_trigger!
    count = ActiveRecord::Base.connection.update(<<~SQL)
      UPDATE page_translations
         SET search_vector = to_tsvector(
               'simple',
               coalesce(title, '') || ' ' ||
               coalesce(abstract, '') || ' ' ||
               coalesce(body, '')
             )
       WHERE search_vector IS NULL
    SQL
    puts "populated #{count} translations"
  end
end

Rake::Task["db:schema:load"].enhance do
  Page.ensure_search_vector_trigger!
end
