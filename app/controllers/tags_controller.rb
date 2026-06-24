class TagsController < ApplicationController

  # Public

  def index
    @page = Page.new :title => "Tags"

    @tags = Tag.limit(500).all
  end

  def show
    tag_name = params[:id]

    if tag_name.match(/^[a-zA-Z0-9_\w\s\-\.\']+$/)
      @tag  = Tag.find_by_name(tag_name)
      @tag  = @tag ? @tag.name : tag_name
      @page = Page.new

      params[:page] = (params[:page].is_a?(Integer) ? params[:page] : 1)

      @pages = Page.heads.tagged_with(@tag).paginate(
        :order    => 'published_at DESC',
        :page     => params[:page],
        :per_page => 23
      )

      respond_to do |format|
        format.html {}
      end
    else
      respond_to do |format|
        format.html { render :nothing => true, :status => 400 }
      end
    end

  end

end
