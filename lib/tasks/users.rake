namespace :users do
  desc "Clear a user's second factor from the shell. LOGIN=name. " \
       "The recovery path when an admin loses their device: elevation " \
       "requires a code, resetting someone else's factor requires " \
       "elevation, and self-service disable requires a current code -- so " \
       "with every admin locked out there is no in-app way back."
  task :clear_otp => :environment do
    login = ENV["LOGIN"].to_s.strip.downcase
    abort "usage: LOGIN=name rake users:clear_otp" if login.empty?

    user = User.find_by(:login => login)
    abort "no such user: #{login}" if user.nil?

    unless user.otp_enrolled?
      puts "#{user.login} has no second factor enrolled; nothing to do."
      next
    end

    user.update_columns(:otp_secret => nil,
                        :otp_pending_secret => nil,
                        :otp_consumed_timestep => nil)
    puts "Cleared the second factor for #{user.login}. " \
         "They can re-enrol under My account."
  end

  desc "Seed last_login_at from whatever the database still remembers. " \
       "There is no login history, so the column is reconstructed once " \
       "from the newest trace each account left: log entries, authorship, " \
       "editing, tagging. Accounts with no trace fall back to their own " \
       "created_at, which tells an ancient untraceable account apart from " \
       "one made yesterday. Dry run unless WRITE=1; FORCE=1 is required " \
       "once any real login has been recorded."
  task :seed_last_login => :environment do
    write = ENV["WRITE"] == "1"
    force = ENV["FORCE"] == "1"

    floor = nil
    if ENV["FLOOR"].present?
      floor = Time.zone.parse(ENV["FLOOR"]) or abort "FLOOR must be YYYY-MM-DD"
    end

    seeded = User.where.not(:last_login_at => nil).count
    if seeded > 0 && write && !force
      abort "#{seeded} accounts already carry a last_login_at, which may be " \
            "a real login. Re-run with FORCE=1 to overwrite them."
    end

    users = User.order(:login).to_a
    ids   = users.map(&:id)

    newest = {
      "log"    => NodeAction.where(:user_id => ids).group(:user_id).maximum(:occurred_at),
      "author" => Page.where(:user_id => ids).group(:user_id).maximum(:created_at),
      "editor" => Page.where(:editor_id => ids).group(:editor_id).maximum(:updated_at),
      "tag"    => ActsAsTaggableOn::Tagging.where(:user_id => ids)
                    .group(:user_id).maximum(:created_at),
      "tagger" => ActsAsTaggableOn::Tagging.where(:tagger_type => "User", :tagger_id => ids)
                    .group(:tagger_id).maximum(:created_at)
    }

    puts "DRY RUN -- nothing written. Re-run with WRITE=1." unless write
    puts format("%-18s %-12s %-8s %s", "login", "seeded", "source", "roles")

    users.each do |user|
      clues        = newest.transform_values { |by_id| by_id[user.id] }.compact
      source, date = clues.max_by { |_, at| at }
      source, date = "created", user.created_at if date.nil?
      source, date = "floor",   floor           if date.nil?

      if date.nil?
        puts format("%-18s %-12s %-8s %s", user.login, "SKIPPED", "none", user.roles.join(","))
        next
      end

      user.update_columns(:last_login_at => date) if write
      puts format("%-18s %-12s %-8s %s", user.login, date.to_date, source, user.roles.join(","))
    end
  end

end
