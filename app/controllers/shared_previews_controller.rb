class SharedPreviewsController < ApplicationController
  def show
    @page = Page.find_by!(preview_token: params[:token])

    if @page.node && @page.node.head_id == @page.id
      redirect_to node_path(@page.node)
      return
    end

    response.headers['X-Robots-Tag'] = 'noindex'
    render template: @page.valid_template, layout: "application"
  end
end
