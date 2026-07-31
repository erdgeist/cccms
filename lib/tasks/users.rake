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
end
