class RevisionsController < ApplicationController
  
  # Private
  
  before_action :login_required
  
  layout 'admin'
  
  def index
    @node = Node.find(params[:node_id])
    @pages = @node.pages.all
  end

  def diff
    @node = Node.find(params[:node_id])

    if @node.pages.length > 1
      params[:start_revision]  ||= @node.pages.all[-2].revision
      params[:end_revision]    ||= @node.pages.all[-1].revision
    else
      params[:start_revision], params[:end_revision] = 1, 1
    end

    @start = @node.resolve_page_reference(params[:start_revision])
    @end   = @node.resolve_page_reference(params[:end_revision])

    if @start.nil? || @end.nil?
      flash[:error] = "That comparison is no longer available."
      redirect_to(node_path(@node)) and return
    end

    @diff_view              = params[:view] == "side_by_side" ? :side_by_side : :inline
    @diff                   = @end.diff_against(@start, view: @diff_view)
    @available_layer_pairs  = @node.available_layer_pairs
    @locked_by_other        = @node.locked? && @node.lock_owner != current_user
  end

  def show
    @node     = Node.find(params[:node_id])
    @page     = @node.pages.find(params[:id])
  end

  def restore
    page = Page.find(params[:id])
    page.node.restore_revision! page.revision
    flash[:notice] = "Revision #{page.revision} restored"
    redirect_to node_path(page.node)
  end
end
