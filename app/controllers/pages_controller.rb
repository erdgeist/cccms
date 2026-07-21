class PagesController < ApplicationController
  
  # Private
  
  before_action :login_required

  def preview
    @page = Page.find(params[:id])
    unless @page.node
      node = Node.find_by(autosave_id: @page.id) ||
             Node.find_by(draft_id: @page.id) ||
             Node.find_by(head_id: @page.id)
      @page.node = node if node
    end

    node ||= @page.node
    if node && node.draft_id == @page.id && node.autosave
      @page = node.autosave
      @page.node = node
    end


    if @page
      template = @page.valid_template
      render(
        template: template,
        layout: "application"
      )
    end
  end
end
