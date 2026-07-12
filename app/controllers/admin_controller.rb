class AdminController < ApplicationController

  # Private

  before_action :login_required

  def index
    @drafts = Node.where("draft_id IS NOT NULL OR autosave_id IS NOT NULL")
      .limit(50).order("updated_at desc")

    @drafts_count = Node.where("draft_id IS NOT NULL OR autosave_id IS NOT NULL").count

    @recent_changes = Node.where(
      "updated_at < ? AND updated_at > ? AND parent_id IS NOT NULL",
      Time.now, Time.now - 14.days
    ).limit(50).order("updated_at desc")

    ordered_with_level = Node.root.self_and_descendants_ordered_with_level
    @sitemap_depth = {}
    ordered_with_level.each { |node, level| @sitemap_depth[node.id] = level }
    @sitemap = ordered_with_level.map(&:first).reject(&:update?)

    @mynodes = Node.joins(:pages)
          .where("pages.user_id = ? or pages.editor_id = ?", current_user, current_user)
          .order("updated_at desc")
          .distinct.first(50)
  end

  def conventions
    @node_kinds = CccConventions::NODE_KINDS
  end

  def search
    @results = Node.editor_search(params[:search_term])

    respond_to do |format|
      format.html do
        render :template => 'admin/search_results'
      end
      format.js do
        render( :json => @results.map do |node|
            if node
              { :id => node.id, :title => node.title, :unique_name => node.unique_name, :node_path => node_path(node) }
            end
          end
        )

      end
    end
  end

  def dashboard_search
    term = params[:search_term]

    if term.blank?
      render json: { tags: [], nodes: [] }
      return
    end

    render json: {
      tags: ActsAsTaggableOn::Tag.named_like(term).limit(5).map { |tag|
        { name: tag.name, tag_path: tags_nodes_path(tags: tag.name) }
      },
      nodes: Node.editor_search(term).limit(10).map { |node|
        { node_id: node.id, title: node.title, unique_name: node.unique_name, node_path: node_path(node) }
      }
    }
  end

  def menu_search
    if params[:search_term] == "Root"
      @results = [Node.root]
    else
      @results = Node.editor_search(params[:search_term])
    end

    respond_to do |format|
      format.html do
        render :partial => 'admin/menu_search_results'
      end

      format.js do
        render( :json => @results.map do |node|
          {:node_id => node.id, :title => node.title, :unique_name => node.unique_name, :node_path => node_path(node)}
          end
        )

      end
    end
  end
end
