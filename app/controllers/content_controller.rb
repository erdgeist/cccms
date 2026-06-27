class ContentController < ApplicationController

  # Public

  before_action :find_page

  # This is the method that renders most of the the public content. It recieves
  # a :locale and a :page_path parameter through the params hash. It looks up
  # the node with the corresponding unique_name attribute. The method doesn't
  # return a node though, the node is really a proxy object for pages. It
  # returns the most recent page associated to this node instead.
  def render_page

    expires_in 20.minutes, :public => true

    if @page and @page.public?
      render(
        :template => @page.valid_template,
        :layout => true
      )
    else
      render(
        :file => Rails.root.join('public', '404.html').to_s,
        :status => 404,
        :layout => false
      )
    end

  end

  def render_gallery
    unless @page.nil?
      @images = @page.assets.images
      render :file => "content/gallery"
    else
      head :not_found
    end
  end

  private
    def find_page
      path = params[:page_path].is_a?(Array) ? params[:page_path].join('/') : params[:page_path]
      if path =~ /^[a-zA-Z\:\/\/\.\-\d_]+$/
        @page = Node.find_page(path)
      else
        @page = nil
      end
    end
end
