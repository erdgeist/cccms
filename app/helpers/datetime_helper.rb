module DatetimeHelper

  def relative_distance(time, now = Time.current)
    seconds = (now - time).abs

    case seconds
    when 0...90
      [1, :minute]
    when 90...45.minutes
      [(seconds / 60).round, :minute]
    when 45.minutes...24.hours
      [(seconds / 1.hour).round, :hour]
    when 24.hours...30.days
      [(seconds / 1.day).round, :day]
    when 30.days...365.days
      [(seconds / 30.days).round, :month]
    else
      [(seconds / 365.days).round, :year]
    end
  end

  RELATIVE_TIME_UNIT_FORMS = {
    en: {
      minute: { one: "minute", other: "minutes" },
      hour:   { one: "hour",   other: "hours" },
      day:    { one: "day",    other: "days" },
      month:  { one: "month",  other: "months" },
      year:   { one: "year",   other: "years" },
    },
    de: {
      # "other" here is the DATIVE plural needed after "vor" -- not the
      # nominative plural you'd use standing alone ("3 Tage" vs "vor 3
      # Tagen"). All five happen to be the nominative plural + "n", since
      # none of them already end in -n or -s -- a property of these five
      # specific words, not a rule to extend to new units without checking.
      minute: { one: "Minute", other: "Minuten" },
      hour:   { one: "Stunde", other: "Stunden" },
      day:    { one: "Tag",    other: "Tagen" },
      month:  { one: "Monat",  other: "Monaten" },
      year:   { one: "Jahr",   other: "Jahren" },
    },
  }.freeze

  def relative_time_phrase(time, now = Time.current)
    count, unit = relative_distance(time, now)
    locale = I18n.locale.to_sym
    forms = RELATIVE_TIME_UNIT_FORMS.fetch(locale, RELATIVE_TIME_UNIT_FORMS[:en])
    word = forms.fetch(unit).fetch(count == 1 ? :one : :other)

    locale == :de ? "vor #{count} #{word}" : "#{count} #{word} ago"
  end

  def admin_datetime(time)
    return "" if time.blank?
    I18n.l(time, :format => :ccc)
  end

  def admin_date(time)
    return "" if time.blank?
    I18n.l(time, :format => :ccc_date)
  end
end
