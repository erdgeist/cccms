class MenuItem < ApplicationRecord
 
  default_scope -> { where(:type => "MenuItem") }
  
  translates    :title
  validates     :title, presence: true
  
  acts_as_list  :scope => :type
  
  before_save   :determine_type_id
  
  def titles=(values)
    values.each do |locale, value|
      Globalize.with_locale(locale) { self.title = value.to_s.strip.presence }
    end
  end
  
  private
  
    def determine_type_id
      case self.class.name
        
      when "MenuItem"
        self.type_id = 1
      when "FeaturedArticle"
        self.type_id = 2
      end
    end
end


class FeaturedArticle < MenuItem
  default_scope -> { where(:type => "FeaturedArticle") }
end
