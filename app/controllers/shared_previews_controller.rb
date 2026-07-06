class SharedPreviewsController < ApplicationController
  def show
    @page = Page.find_by!(preview_token: params[:token])
    node  = @page.node

    was_published    = @page.published_at.present?
    superseded       = was_published && node && node.head_id != @page.id
    currently_public = was_published && node && node.head_id == @page.id && @page.public?

    if superseded || currently_public
      redirect_to node_path(node)
      return
    end

    response.headers['X-Robots-Tag'] = 'noindex'
    render template: @page.valid_template, layout: "application"
  end
end
