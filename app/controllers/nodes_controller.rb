class NodesController < ApplicationController
  include PinnedToDefaultLocale

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
                              :revert,
                              :trash,
                              :restore_from_trash
                            ]

  def index
    @nodes = Node.root.descendants.includes(:head, :draft)
      .order('id DESC')
      .paginate(:page => params[:page], :per_page => 25)
  end

  def new
    @node = Node.new node_create_params
    @selected_kind = CccConventions::NODE_KINDS.key?(params[:kind]) ? params[:kind] : "generic"
    @parent = Node.find(params[:parent_id]) if params.has_key?(:parent_id)
    @attach_asset = Asset.find(params[:asset_id]) if params.has_key?(:asset_id)
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
      NodeAction.record!(:node => @node, :page => @node.draft, :user => current_user,
                          :action => "create",
                          :title => params[:title], :path => @node.unique_name)

      if params[:asset_id].present? && (asset = Asset.find(params[:asset_id]))
        result = @node.attach_asset!(asset, :user => current_user,
                                      :headline => params[:asset_headline].present?)
        flash[:notice] = t("flash.nodes.created_with_attachment", :name => asset.name)
        flash[:notice] += " " + t("flash.common.now_headline") if result[:headline] == :set
        flash[:error]   = t("flash.common.headline_ineligible") if result[:headline] == :not_eligible
      end

      redirect_to(edit_node_path(@node))
    else
      @selected_kind = CccConventions::NODE_KINDS.key?(params[:kind]) ? params[:kind] : "generic"
      @parent = Node.find(params[:parent_id]) if params.has_key?(:parent_id)
      @attach_asset = Asset.find(params[:asset_id]) if params.has_key?(:asset_id)
      render :new
    end
  end

  def show
    @page = @node.draft || @node.head
    @translations = @page.translation_summary
    @page_actions = NodeAction.where(:page_id => @node.pages.select(:id))
                              .order(:occurred_at, :id)
                              .group_by(&:page_id)
  end

  def edit
    freshly_locked = @node.lock_owner != current_user
    @node.lock_for_editing!( current_user )
    @page = @node.autosave || @node.draft || @node.head

    if @node.autosave
      flash.now[:notice] = t("flash.nodes.autosave_banner")
    elsif freshly_locked
      flash.now[:notice] ||= t("flash.nodes.locked_ready")
    end
  rescue LockedByAnotherUser => e
    flash[:error] = t("flash.common.locked_by_other")
    redirect_to(request.referer || node_path(@node))
  end

  def update
    @node.update(node_update_params)
    @node.autosave!( page_params.merge(:tag_list => params[:tag_list]), current_user )
    @node.save_draft!(current_user)

    flash[:notice] = t("flash.nodes.draft_saved")
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

    if params[:unlock_exit].present?
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
    @node.update(node_update_params)
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

 def trash
    if @node.trash!(current_user)
      flash[:notice] = t("flash.nodes.trashed")
      redirect_to trashed_nodes_path
    else
      flash[:notice] = t("flash.nodes.already_trashed")
      redirect_to node_path(@node)
    end
  rescue LockedByAnotherUser
    flash[:error] = t("flash.common.locked_by_other")
    redirect_to node_path(@node)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  end

  def restore_from_trash
    parent = Node.find(params[:parent_id])
    @node.restore_from_trash!(parent, current_user)
    flash[:notice] = t("flash.nodes.restored")
    redirect_to node_path(@node)
  rescue ActiveRecord::RecordNotFound
    flash[:error] = t("flash.nodes.restore_target_missing")
    redirect_to node_path(@node)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  end

  def destroy
    @node.destroy_from_trash!(current_user)
    flash[:notice] = t("flash.nodes.deleted")
    redirect_to trashed_nodes_path

  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    flash[:error] = e.message
    redirect_to node_path(@node)
  end

  def publish
    @node.publish_draft!(current_user)
    flash[:notice] = t("flash.nodes.published")
    redirect_to node_path(@node)
  end

  def unlock
    if @node.unlock!
      flash[:notice] = t("flash.nodes.unlocked")
    else
      flash[:notice] = t("flash.nodes.already_unlocked")
    end

    redirect_to node_path(@node)
  end

  def generate_shared_preview
    @node = Node.find(params[:id])
    if @node.draft
      @node.draft.ensure_preview_token!
      flash[:notice] = t("flash.nodes.preview_created")
    else
      flash[:notice] = t("flash.nodes.preview_needs_draft")
    end
    redirect_to node_path(@node)
  end

  def revoke_shared_preview
    @node = Node.find(params[:id])
    @node.draft.revoke_preview_token! if @node.draft
    flash[:notice] = t("flash.nodes.preview_revoked")
    redirect_to node_path(@node)
  end

  def parameterize_preview
    render plain: slug_for(params[:title])
  end

  # Filter functions for admin views
  def drafts
    @nodes = index_matching(Node.work_in_progress)
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

  def trashed
    @nodes = Node.trash.children.order(:slug)
                 .paginate(:page => params[:page], :per_page => 50)
  end

  private

    def slug_for(title)
      title.to_s.parameterize
    end

    def node_create_params
      params.fetch(:node, {}).permit(:slug, :parent_id)
    end

    def node_update_params
      params.fetch(:node, {}).permit(:staged_slug, :staged_parent_id)
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
