class RssController < ApplicationController
  
  before_action :get_host

  def updates
    expires_in 31.minutes, :public => true
    I18n.locale = I18n.default_locale

    @items = feed_items("update")

    respond_to do |format|
      format.xml {}
      format.rdf {}
    end
  end

  def tag_updates
    expires_in 31.minutes, :public => true
    I18n.locale = I18n.default_locale

    @tag   = params[:tag]
    @items = feed_items(@tag)

    respond_to do |format|
      format.xml {}
    end
  end

  protected

    def feed_items tag
      Page.aggregate(:tags => tag.to_s.downcase,
                     :limit => 20,
                     :order_by => "published_at",
                     :order_direction => "DESC")
    end

    def get_host
      @host = request.protocol + request.host_with_port
    end
  
end
