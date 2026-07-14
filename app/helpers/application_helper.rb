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

  def resolve_kind_text(value)
    value.respond_to?(:call) ? value.call : value
  end

  # Cache-busts a static file living directly under public/, outside the
  # asset pipeline -- used by both the admin and public layouts, since
  # neither loads its static CSS/JS through Sprockets (admin_bundle.js is
  # the one exception; it already gets pipeline fingerprinting for free).
  # Raises rather than silently omitting the version param: a missing
  # file here means the page is already broken, and failing loudly beats
  # a confusing "why is the browser still showing the old version" report
  # days later.
  def mtime_busted_path(path)
    file = Rails.public_path.join(path.sub(%r{\A/}, ""))
    raise "Static asset not found for cache-busting: #{path} (looked for #{file})" unless File.exist?(file)
    "#{path}?v=#{File.mtime(file).to_i}"
  end
end
