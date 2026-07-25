class RevisionsController < ApplicationController
  
  # Private
  
  before_action :login_required
  
  layout 'admin'

  def index
    @node   = Node.find(params[:node_id])
    @pages  = @node.pages.all
    @locale = resolve_locale(params[:locale])
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
      flash[:error] = t("flash.revisions.unavailable")
      redirect_to(node_path(@node)) and return
    end

    @locale_summary  = @end.locale_diff_summary(@start)
    requested_locale = params[:locale].presence&.to_sym
    default_locale    = @locale_summary.find { |s| s[:changed] }&.dig(:locale) || I18n.default_locale
    @locale = @locale_summary.any? { |s| s[:locale] == requested_locale } ? requested_locale : default_locale

    @diff_view              = params[:view] == "side_by_side" ? :side_by_side : :inline
    @diff                   = @end.diff_against(@start, view: @diff_view, locale: @locale)
    @available_layer_pairs  = @node.available_layer_pairs
    @locked_by_other        = @node.locked? && @node.lock_owner != current_user
  end

  def show
    @node     = Node.find(params[:node_id])
    @page     = @node.pages.find(params[:id])
    @locale   = resolve_locale(params[:locale])
  end

  def restore
    page = Page.find(params[:id])
    page.node.restore_revision! page.revision, current_user
    flash[:notice] = t("flash.revisions.restored", :rev => page.revision)
    redirect_to node_path(page.node)
  end

  private

    def resolve_locale(requested)
      candidate = requested.presence&.to_sym
      allowed   = [I18n.default_locale] + Page.non_default_locales
      allowed.include?(candidate) ? candidate : I18n.default_locale
    end
end
