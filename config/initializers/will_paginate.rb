Rails.application.config.to_prepare do
  WillPaginate::ViewHelpers.pagination_options[:inner_window] = 1
  WillPaginate::ViewHelpers.pagination_options[:outer_window] = 0
end
