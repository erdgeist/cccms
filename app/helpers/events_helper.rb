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
end
