class PageTranslationsController < ApplicationController
  layout 'admin'

  before_action :login_required
  before_action :find_node
  before_action :find_locale, :only => [:show, :edit, :update, :autosave, :destroy]

  def show
    @page = @node.draft || @node.head
    @translation         = @page.translations.find_by(:locale => @locale)
    @default_translation = @page.translations.find_by(:locale => I18n.default_locale)
  end

  def edit
    @node.lock_for_editing!(current_user)
    @page = @node.draft || @node.head
    @translation = @page.translations.find_by(:locale => @locale)
  rescue LockedByAnotherUser => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  end

  def update
    Globalize.with_locale(@locale) { @node.autosave!(translation_params, current_user) }
    @node.save_draft!(current_user)
    flash[:notice] = "#{@locale.upcase} translation saved. Publish the draft to make it live."

    if params[:commit] == "Save + Unlock + Exit"
      @node.unlock!
      redirect_to node_path(@node)
    else
      redirect_to edit_node_translation_path(@node, @locale)
    end
  rescue LockedByAnotherUser => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  end

  def autosave
    Globalize.with_locale(@locale) { @node.autosave!(translation_params, current_user) }
    head :ok
  rescue LockedByAnotherUser => e
    render plain: e.message, status: :locked
  rescue ActiveRecord::RecordInvalid => e
    render plain: e.message, status: :unprocessable_entity
  rescue StandardError => e
    render plain: "Autosave failed", status: :internal_server_error
  end

  def destroy
    base = @node.draft || @node.head
    unless base && base.translated_locales.include?(@locale)
      flash[:error] = "No #{@locale.to_s.upcase} translation exists to remove."
      return redirect_to node_path(@node)
    end

    if (base.translated_locales - [@locale]).empty?
      flash[:error] = "Can't remove the only remaining translation."
      return redirect_to node_path(@node)
    end

    draft = ensure_editable_draft
    draft.translations.where(:locale => @locale).delete_all
    draft.reload

    NodeAction.record!(:node => @node, :page => draft, :user => current_user,
                        :action => "translation_destroy", :locale => @locale)

    flash[:notice] = "#{@locale.upcase} translation removed from the draft. Publish to make this permanent."
    redirect_to node_path(@node)
  rescue LockedByAnotherUser => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  end

  private

    def find_node
      @node = Node.find(params[:node_id])
    end

    # Every remaining action's :translation_locale is already
    # router-constrained to non-default locales, so this should never
    # actually fire in practice -- it's a deliberate second check, kept
    # as a drift detector in case the route constraint and this list
    # (both driven by Page.non_default_locales) ever disagree.
    def find_locale
      candidate = params[:translation_locale].to_s.to_sym
      unless Page.non_default_locales.include?(candidate)
        raise ActionController::RoutingError, "Unknown or default locale"
      end
      @locale = candidate
    end

    # Never mutates head directly. Locks first (same guard as the
    # primary editor), then reuses an existing draft or creates one --
    # deliberately not going through the autosave buffer: this is a
    # plain, explicit Save, not a live-typing surface.
    def ensure_editable_draft
      @node.lock_for_editing!(current_user)
      @node.draft || @node.create_new_draft(current_user)
    end

    def translation_params
      params.fetch(:page, {}).permit(:title, :abstract, :body)
    end
end
