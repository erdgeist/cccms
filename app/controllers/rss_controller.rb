class RssController < ApplicationController
  
  before_action :get_host
  
  def updates
    expires_in 31.minutes, :public => true
    
    I18n.locale = :de
  
    @items = Page.heads
      .joins("JOIN taggings ON taggings.taggable_id = pages.id
            AND taggings.taggable_type = 'Page'
            AND taggings.context = 'tags'")
      .joins("JOIN tags ON tags.id = taggings.tag_id")
      .where("LOWER(tags.name) = ?", "update")
      .order("published_at DESC").limit(20)

    respond_to do |format|
      format.xml {}
      format.rdf {}
    end
  end

  def tag_updates
    expires_in 31.minutes, :public => true

    I18n.locale = I18n.default_locale
    @tag  = params[:tag]
    @items = Page.heads
      .joins("JOIN taggings ON taggings.taggable_id = pages.id
          AND taggings.taggable_type = 'Page'
          AND taggings.context = 'tags'")
      .joins("JOIN tags ON tags.id = taggings.tag_id")
      .where("LOWER(tags.name) = ?", @tag.downcase)
      .order("published_at DESC").limit(20)

    respond_to do |format|
      format.xml {}
    end
  end

  protected
    
    def get_host
      @host = request.protocol + request.host_with_port
    end
  
end
