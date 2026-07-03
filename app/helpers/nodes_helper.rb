module NodesHelper
  
  def title_for_node node
    if node.head
      node.head.title
    else
      if not node.draft or not node.draft.title
        logger.error "Missing title in node #{node.id}"
        return "NO TITLE"
      end
      node.draft.title
    end
  end
  
  
  def truncated_title_for_node node
    if (title = title_for_node node) && title.size > 20
      "<span title='#{title}'>#{truncate(title, 40)}</span>"
    else
      title
    end
  end
  
  def custom_page_templates
    Page.custom_templates.map {|x| [x.gsub("_", " ").titlecase, x]}
  end
  
  def user_list
    User.all.map {|u| [u.login, u.id]}
  end

  def event_information
    events = @node.events.order(:start_time)
    items = events.map do |event|
      safe_join([
        "#{event.start_time&.to_fs(:db)} - #{event.end_time&.to_fs(:db)} > ",
        link_to('edit', edit_event_path(event)),
      ])
    end
    safe_join([
      safe_join(items, ' | '),
      ' > ',
      link_to('add event', new_event_path(:node_id => @node.id))
    ])
  end

  DEFAULT_EVENT_TAG_BY_PAGE_TAG = {
    'erfa-detail'       => 'open-day',
    'chaostreff-detail' => 'open-day'
  }.freeze

  def default_event_tag_mapping(page)
    page_tags = page.tag_list
    DEFAULT_EVENT_TAG_BY_PAGE_TAG.find { |page_tag, _| page_tags.include?(page_tag) }
  end

  def default_event_tag_list(page)
    default_event_tag_mapping(page)&.last
  end

  def event_schedule_text(event)
    if event.rrule.present?
      recurrence = event.humanize_rrule(I18n.locale)
      if recurrence
        time = event.start_time&.strftime("%H:%M")
        time ? "#{recurrence} #{t(:event_schedule_time, time: time)}" : recurrence
      else
        "#{event.rrule} (#{t(:event_schedule_unrecognized)})"
      end
    elsif event.start_time
      I18n.l(event.start_time, format: :long)
    else
      t(:event_schedule_none)
    end
  end
end
