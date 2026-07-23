namespace :tags do
  desc "Merge tags differing only in case into one lowercase tag and " \
       "lowercase every remaining name. Idempotent; safe to re-run."
  task :merge_case_duplicates => :environment do
    merged = renamed = 0

    ActiveRecord::Base.transaction do
      ActsAsTaggableOn::Tag.pluck(Arel.sql("DISTINCT LOWER(name)")).each do |lower|
        group  = ActsAsTaggableOn::Tag.where("LOWER(name) = ?", lower).order(:id).to_a
        keeper = group.find { |t| t.name == lower } || group.first

        (group - [keeper]).each do |dup|
          dup.taggings.find_each do |tagging|
            duplicate = ActsAsTaggableOn::Tagging.where(
              :tag_id => keeper.id,
              :taggable_type => tagging.taggable_type,
              :taggable_id   => tagging.taggable_id,
              :context       => tagging.context,
              :tagger_type   => tagging.tagger_type,
              :tagger_id     => tagging.tagger_id).exists?
            duplicate ? tagging.destroy : tagging.update!(:tag_id => keeper.id)
          end
          dup.reload.destroy!
          merged += 1
        end

        if keeper.name != lower
          keeper.update!(:name => lower)
          renamed += 1
        end
        ActsAsTaggableOn::Tag.reset_counters(keeper.id, :taggings)
      end
    end

    puts "Merged #{merged} duplicate tags, lowercased #{renamed} names"
  end
end
