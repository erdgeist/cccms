class PagesController < ApplicationController
  
  # Private
  
  before_action :login_required

  def preview
    @page = Page.find(params[:id])

    if @page
      template = @page.valid_template
      render(
        template: template,
        layout: "application"
      )
    end
  end
end
