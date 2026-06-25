require 'will_paginate/view_helpers/action_view'

WillPaginate::ActionView::LinkRenderer.class_eval do
  def url(page)
    path = @template.request.path
    page_param = WillPaginate::PageNumber(page)
    if page_param == 1
      path
    else
      "#{path}?#{@options[:param_name]}=#{page}"
    end
  end
end
