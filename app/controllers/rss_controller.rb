class RssController < ApplicationController
  
  before_filter :authenticate, :only => :recent_changes
  before_filter :get_host
  
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

  def recent_changes
    @items = Page.where(
      "updated_at < ? AND updated_at > ?", Time.now, Time.now - 14.days
    ).limit(20).order("updated_at desc")
  end
  
  protected
    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == "recent" && password == "d@t3N+kLAu-23"
      end
    end
    
    def get_host
      @host = request.protocol + request.host_with_port
    end
  
end
