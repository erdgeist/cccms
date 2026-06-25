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
    @node.slug = params[:title].parameterize.to_s
   
    if @node.save
      @node.draft.update_attributes(:title => params[:title])
      case params[:kind]
        when "update"
          @node.draft.tag_list.add("update")
        when "press_release"
          @node.draft.tag_list.add("update", "pressemitteilung")
      end
      @node.draft.save!
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
    @node.update_attributes(node_params)
    @draft = @node.find_or_create_draft current_user
    @draft.tag_list = params[:tag_list]
    if @draft.update_attributes( page_params )
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
  
  private

    def node_params
      params.fetch(:node, {}).permit(:slug, :parent_id)
    end

    def page_params
      params.fetch(:page, {}).permit(:title, :abstract, :body, :template_name, :published_at, :user_id)
    end
  
    def find_node
      @node = Node.find(params[:id])
    end
    
    def find_parent
      case params[:kind]
      when "top_level"
        Node.root.id
      when "update"
        Update.find_or_create_parent.id
      when "press_release"
        Update.find_or_create_parent.id
      when "generic"
        if params[:parent_id] && Node.find(params[:parent_id])
          params[:parent_id]
        else
          nil
        end
      end
    end
end
