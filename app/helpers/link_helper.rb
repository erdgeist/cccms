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
    if params[:page_path]
      active = (params[:page_path].join("/") == path.sub(/^\//, ""))
    end
    
    active_class = active ? {:class => 'active'} : {:class => 'inactive'}
    
    html_options = html_options.merge(active_class)
    
    params[:locale] ||= I18n.locale
    
    link_to( 
      title, {
        :controller => :content,
        :action => :render_page,
        :locale => params[:locale],
        :page_path => path.sub(/^\//, "").split("/")
      },
      html_options
    )
  end
  
  def selected? controller_name
    if params[:controller] == controller_name
      return :class => "selected"
    end
  end
end