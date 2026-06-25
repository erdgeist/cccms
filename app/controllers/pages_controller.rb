class PagesController < ApplicationController
  
  # Private
  
  before_action :login_required
  
  def preview
    @page = Page.find(params[:id])
    
    if @page
      template = @page.valid_template
      render(
        :file => template,
        :layout => "application"
      )
    end
    
  end
  
  
  def sort_images
    page = Page.find(params[:id])
    page.update_assets(params[:images])
    
    head :ok
  end
end
