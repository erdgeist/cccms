class SharedPreviewsController < ApplicationController
  def show
    @page = Page.find_by!(preview_token: params[:token])
    node  = @page.node

    if node
      is_head  = node.head_id  == @page.id
      is_draft = node.draft_id == @page.id

      currently_public = is_head && @page.public?
      superseded        = !is_head && !is_draft

      if superseded || currently_public
        redirect_to @page.public_link
        return
      end
    end

    response.headers['X-Robots-Tag'] = 'noindex'
    render template: @page.valid_template, layout: "application"
  end
end
