class AdminController < ApplicationController
  
  # Private
  
  before_filter :login_required

  def index
    @drafts = Node.all(
      :limit => 20,
      :order => "updated_at desc",
      :conditions => ["draft_id IS NOT NULL"]
    )
    @recent_changes = Node.all(
      :limit => 20,
      :order => "updated_at desc",
      :conditions => [ 
        "updated_at < ? AND updated_at > ? AND parent_id IS NOT NULL", Time.now, Time.now-14.days
      ]
    )

    all_nodes = Node.root.self_and_descendants
    @sitemap_depth = {}
    Node.each_with_level(all_nodes) do |node, level|
      @sitemap_depth[node.id] = level
    end
    @sitemap = all_nodes.to_a.sort! { |node1,node2| node1.lft <=> node2.lft }.delete_if { |node| node.update? }
  end
  
  def search
    @results = Node.search params[:search_term], :per_page => 1000
    
    respond_to do |format|
      format.html do
        render :template => 'admin/search_results.html'
      end
      format.js do 
        render( :json => @results.map do |node| 
            if node
              {:id => node.id, :title => node.title, :edit_path => node_path(node)}
            end
          end
        )
        
      end 
    end
  end
  
  def menu_search
    if params[:search_term] == "Root"
      @results = [Node.root]
    else
      @results = Node.search params[:search_term]
    end
    
    respond_to do |format|
      format.html do
        render :partial => 'admin/menu_search_results'
      end
      
      format.js do 
        render( :json => @results.map do |node| 
          {:node_id => node.id, :title => node.title, :unique_name => node.unique_name} 
          end
        )
        
      end 
    end
  end
  
end
