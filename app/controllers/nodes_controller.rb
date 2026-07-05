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
                              :unlock
                            ]

  def index
    @nodes = Node.root.descendants.includes(:head, :draft)
      .order('id DESC')
      .paginate(:page => params[:page], :per_page => 25)
  end

  def new
    @node = Node.new node_params
    if params.has_key?(:parent_id)
      @parent_id = params[:parent_id]
      @parent_name = Node.find(@parent_id).title
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
      render :new
    end
  end
  
  def show
    node = Node.find(params[:id])
    node.wipe_draft!
    @page = node.draft || node.head
  end

  def edit
    begin
      @draft = @node.find_or_create_draft( current_user )
    rescue LockedByAnotherUser => e
      flash[:error] = e.message
      if request.referer
        redirect_to request.referer || node_path(@node)
      else
        redirect_to node_path(@node)
      end
    end
  end

  def update
    @node.update(node_params)
    @draft = @node.find_or_create_draft current_user
    @draft.tag_list = params[:tag_list]
    if @draft.update( page_params )
      flash[:notice] = "Draft has been saved: #{Time.now}"
      respond_to do |format|
        format.html { redirect_to edit_node_path(@node) }
        format.js
      end
    else
      render :action => :edit
    end
  end

  def destroy
    @node.destroy
  end
  
  def publish
    @node.publish_draft!
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

  def parameterize_preview
    render plain: slug_for(params[:title])
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
end
