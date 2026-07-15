class NodesController < ApplicationController

  # Private

  layout 'admin'

  before_action :login_required
  before_action :find_node, :only => [
                              :show,
                              :edit,
                              :update,
                              :destroy,
                              :publish,
                              :unlock,
                              :autosave,
                              :revert
                            ]

  around_action :pin_to_default_locale, :only => [:show, :edit, :update, :autosave]

  def index
    @nodes = Node.root.descendants.includes(:head, :draft)
      .order('id DESC')
      .paginate(:page => params[:page], :per_page => 25)
  end

  def new
    @node = Node.new node_params
    @selected_kind = CccConventions::NODE_KINDS.key?(params[:kind]) ? params[:kind] : "generic"
    if params.has_key?(:parent_id)
      @parent_id = params[:parent_id]
      parent = Node.find(@parent_id)
      @parent_name = parent.title
      @parent_unique_name = parent.current_unique_name
    end
  end

  def create
    params[:title] ||= ""

    @node = Node.new
    @node.parent_id = find_parent
    @node.slug = slug_for(params[:title])

    config = CccConventions::NODE_KINDS[params[:kind]]

    if @node.save
      @node.draft.update(:title => params[:title])
      Array(config && config[:tags]).each { |t| @node.draft.tag_list.add(t) }
      @node.draft.save!

      @node.update!(default_template_name: config[:template]) if config && config[:template]

      redirect_to(edit_node_path(@node))
    else
      @selected_kind = CccConventions::NODE_KINDS.key?(params[:kind]) ? params[:kind] : "generic"
      if params[:parent_id].present?
        @parent_id = params[:parent_id]
        @parent_name = Node.find(@parent_id).title
      end
      render :new
    end
  end

  def show
    @page = @node.draft || @node.head
    @translations = @page.translation_summary
  end

  def edit
    freshly_locked = @node.lock_owner != current_user
    @node.lock_for_editing!( current_user )
    @page = @node.autosave || @node.draft || @node.head

    if @node.autosave
      flash.now[:notice] =
        "This page has unsaved changes from a previous session, shown below. " \
        "Save to keep them, or use \"Discard Autosave\" below to go back to the last saved version."
    elsif freshly_locked
      flash.now[:notice] = "Node locked and ready to edit"
    end
  rescue LockedByAnotherUser => e
    flash[:error] = e.message
    redirect_to(request.referer || node_path(@node))
  end

  def update
    @node.update(node_params)
    @node.autosave!( page_params.merge(:tag_list => params[:tag_list]), current_user )
    @node.save_draft!(current_user)

    flash[:notice] = "Draft saved. Publish your changes in the Status section once you're done."
    flash[:status_path] = node_path(@node)

    if @node.draft.translated_locales.size > 1
      stale_locale = @node.draft.translated_locales.find do |locale|
        @node.draft.outdated_translations?(locale: locale)
      end
      if stale_locale
        flash[:stale_locale] = stale_locale
        flash[:stale_locale_path] = edit_node_path(@node, locale: stale_locale)
      end
    end

    if params[:commit] == "Save + Unlock + Exit"
      @node.unlock!
      redirect_to node_path(@node)
    else
      redirect_to edit_node_path(@node)
    end
  rescue LockedByAnotherUser => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  rescue ActiveRecord::RecordInvalid
    @page = @node.autosave || @node.draft || @node.head
    render :action => :edit
  end

  def autosave
    @node.update(node_params)
    @node.autosave!( page_params.merge(:tag_list => params[:tag_list]), current_user )
    head :ok
  rescue LockedByAnotherUser => e
    render plain: e.message, status: :locked
  rescue ActiveRecord::RecordInvalid => e
    render plain: e.message, status: :unprocessable_entity
  rescue StandardError => e
    render plain: "Autosave failed", status: :internal_server_error
  end

  def revert
    @node.lock_for_editing!(current_user)
    @node.revert!(current_user)

    if params[:return_to].present?
      redirect_to safe_return_to(params[:return_to])
    elsif @node.draft
      redirect_to edit_node_path(@node)
    else
      redirect_to node_path(@node)
    end
  rescue LockedByAnotherUser => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  end

  def destroy
    @node.destroy
  end

  def publish
    @node.publish_draft!(current_user)
    flash[:notice] = "Draft has been published"
    redirect_to node_path(@node)
  end

  def unlock
    if @node.unlock!
      flash[:notice] = "Node unlocked"
    else
      flash[:notice] = "Already unlocked"
    end

    redirect_to node_path(@node)
  end

  def generate_shared_preview
    @node = Node.find(params[:id])
    if @node.draft
      @node.draft.ensure_preview_token!
      flash[:notice] = "Shareable preview link created - see below."
    else
      flash[:notice] = "Create or edit a draft first - shared preview links are only available for pages with an active draft."
    end
    redirect_to node_path(@node)
  end

  def revoke_shared_preview
    @node = Node.find(params[:id])
    @node.draft.revoke_preview_token! if @node.draft
    flash[:notice] = "Shareable preview link revoked."
    redirect_to node_path(@node)
  end

  def parameterize_preview
    render plain: slug_for(params[:title])
  end

  # Filter functions for admin views
  def drafts
    @nodes = index_matching(Node.drafts_and_autosaves)
  end

  def recent
    @nodes = index_matching(Node.recently_changed)
  end

  def mine
    base = Node.joins(:pages)
      .where("pages.user_id = ? or pages.editor_id = ?", current_user, current_user)
      .distinct
    @nodes = index_matching(base)
  end

  def chapters
    @kind_keys = Array(params[:kinds]) & %w[erfa chaostreff]
    @kind_keys = %w[erfa chaostreff] if @kind_keys.empty?
    tags = @kind_keys.flat_map { |key| CccConventions::NODE_KINDS[key][:tags] }
    @nodes = nodes_matching_tags(tags)
  end

  def tags
    tags = params[:tags].to_s.split(',').map(&:strip).reject(&:blank?)
    @nodes = nodes_matching_tags(tags)
  end

  def sitemap
    @sitemap = Node.root.self_and_descendants_ordered_with_level
    @sitemap_descendant_counts = descendant_counts_for(@sitemap)
  end

  private

    def slug_for(title)
      title.to_s.parameterize
    end

    def node_params
      params.fetch(:node, {}).permit(:slug, :parent_id, :staged_slug, :staged_parent_id)
    end

    def page_params
      params.fetch(:page, {}).permit(:title, :abstract, :body, :template_name, :published_at, :user_id)
    end

    def find_node
      @node = Node.find(params[:id])
    end

    def find_parent
      case params[:kind]
      when "generic"
        if params[:parent_id] && Node.find(params[:parent_id])
          params[:parent_id]
        else
          nil
        end
      else
        config = CccConventions::NODE_KINDS[params[:kind]]
        config && config[:parent] ? config[:parent].call.id : nil
      end
    end

    def pin_to_default_locale
      Globalize.with_locale(I18n.default_locale) { yield }
    end

    def descendant_counts_for(ordered_with_level)
      counts = Hash.new(0)
      stack = [] # [node, level, index]
      ordered_with_level.each_with_index do |(node, level), index|
        while stack.any? && stack.last[1] >= level
          ancestor_node, _ancestor_level, ancestor_index = stack.pop
          counts[ancestor_node.id] = index - ancestor_index - 1
        end
        stack << [node, level, index]
      end
      total = ordered_with_level.length
      while stack.any?
        ancestor_node, _ancestor_level, ancestor_index = stack.pop
        counts[ancestor_node.id] = total - ancestor_index - 1
      end
      counts
    end

    def nodes_matching_tags(tags)
      matching_pages = Page.tagged_with(tags, any: true).reselect(:id)
      base = Node.where(head_id: matching_pages).or(Node.where(draft_id: matching_pages))
      index_matching(base)
    end

    def index_matching(base_scope)
      scope = base_scope.includes(:head, :draft)
      scope = scope.merge(Node.editor_search(params[:q])) if params[:q].present?
      scope.order("nodes.updated_at desc").paginate(page: params[:page], per_page: 25)
    end
end
