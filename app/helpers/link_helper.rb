module LinkHelper
  
  def content_path_helper path_array
    url_for(
      :controller => :content,
      :action => :render_page,
      :locale => params[:locale] || I18n.locale,
      :page_path => path_array
    )
  end
  
  def content_url_helper path_array
    request.protocol + request.host_with_port + content_path_helper(path_array)
  end
  
  def link_to_path title, path, html_options = {}
    return "" if path.nil?

    if params[:page_path]
      page_path = params[:page_path].is_a?(Array) ? params[:page_path].join("/") : params[:page_path]
      active = (page_path == path.sub(/^\//, ""))
    end

    active_class = active ? {:class => 'active'} : {:class => 'inactive'}

    html_options = html_options.merge(active_class)

    locale = params[:locale] || I18n.locale

    link_to(
      title,
      content_path(path.sub(/^\//, ""), :locale => locale),
      html_options
    )
  end

  def selected? controller_name
    if params[:controller] == controller_name
      return :class => "selected"
    end
  end
  
  def unlock_link
    message = "Are you sure you want to unlock?\n" +
              "Locked by #{@node.lock_owner.login}\n" +
              "Last modified #{@page.updated_at.to_s(:db)}"
    
    link_to(
      'Unlock', unlock_node_path(@node), :method => :put, :data => { :confirm => message }
    )
  end
  
end
