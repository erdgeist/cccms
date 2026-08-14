class AdminController < ApplicationController
  include PinnedToDefaultLocale

  # Private

  before_action :login_required

  def index
    scope         = Node.work_in_progress(current_user_id: current_user.id)
    @drafts_total = scope.reorder(nil).count
    @drafts       = scope.includes(:head, :draft, :lock_owner).limit(5)
    @actions = NodeAction.order(:occurred_at => :desc, :id => :desc).limit(5)
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
          { :node_id => node.id, :title => node.title,
            :unique_name => node.unique_name, :node_path => node_path(node),
            :needs_redaktion => !current_user.may_change_live?(node) }
          end
        )

      end
    end
  end

  # Deliberately raises, to verify the error-log tripwire end to end.
  # Behind login_required like the rest of the controller; harmless --
  # the visitor gets the ordinary 500 page.
  def boom
    raise "Deliberate test exception via admin/boom"
  end
end
