class RelatedAsset < ApplicationRecord
  belongs_to :page
  belongs_to :asset
  
  acts_as_list :scope => :page_id

  default_scope -> { order("position ASC") }

  validate :headline_only_for_images

  private

    def headline_only_for_images
      return unless asset
      errors.add(:headline, "can only be set on image assets") if headline? && !asset.image?
    end
end
