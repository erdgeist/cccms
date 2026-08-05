require 'cgi'

module EventsHelper
  # Insert a zero-width break opportunity after each semicolon, so a long
  # RRULE can wrap at a clause boundary instead of overflowing its column.
  # Deliberately <wbr>, not ellipsis -- unlike a URL, an RRULE's trailing
  # characters (BYDAY, BYMONTH, etc.) are usually the most specific part,
  # and truncating them would hide exactly the wrong end of the string.
  def rrule_with_break_opportunities(rrule)
    return "" if rrule.blank?
    raw(rrule.split(';', -1).map { |part| CGI.escapeHTML(part) }.join(';<wbr>'))
  end

  def external_url_link(url)
    return nil if url.blank?
    return h(url) unless url.match?(%r{\Ahttps?://}i)
    link_to(url, url, :target => "_blank", :rel => "noopener")
  end

  def event_date_range(event)
    return t("events.schedule.none") if event.start_time.blank?

    from = event.start_time
    to   = event.end_time

    return one_day_range(from, event.allday) if to.blank? || to.to_date == from.to_date

    if !event.allday && (to - from) <= 12.hours
      return t("events.schedule.evening",
               :date => admin_date(from),
               :from => I18n.l(from, :format => :time),
               :to   => I18n.l(to,   :format => :time))
    end

    key = from.year == to.year && from.month == to.month ? :same_month : :spanning
    t("events.schedule.#{key}",
       :from_day   => from.day, :to_day => to.day,
       :from_month => I18n.l(from, :format => :ccc_month),
       :to_month   => I18n.l(to,   :format => :ccc_month),
       :from_full  => admin_date(from), :to_full => admin_date(to))
  end

  private

    def one_day_range(from, allday)
      return admin_date(from) if allday
      admin_datetime(from)
    end
end
