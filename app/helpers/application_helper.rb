# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def form_error_messages(form_object)
    object = form_object.is_a?(ActionView::Helpers::FormBuilder) ? form_object.object : form_object
    return "" unless object && object.errors.any?
    content_tag(:div, :class => "error_messages") do
      content_tag(:ul) do
        object.errors.full_messages.map do |msg|
          content_tag(:li, msg)
        end.join.html_safe
      end
    end
  end

  def safe_return_to(url)
    return events_path if url.blank?
    uri = URI.parse(url)
    return events_path if uri.host.present?
    return events_path unless url.start_with?('/')
    url
  rescue URI::InvalidURIError
    events_path
  end
end
