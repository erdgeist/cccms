module RruleHumanizer
  extend ActiveSupport::Concern

  WEEKDAY_NAMES = {
    de: { "MO"=>"Montag","TU"=>"Dienstag","WE"=>"Mittwoch","TH"=>"Donnerstag","FR"=>"Freitag","SA"=>"Samstag","SU"=>"Sonntag" },
    en: { "MO"=>"Monday","TU"=>"Tuesday","WE"=>"Wednesday","TH"=>"Thursday","FR"=>"Friday","SA"=>"Saturday","SU"=>"Sunday" }
  }.freeze

  WEEKDAY_NAMES_ADVERBIAL = {
    de: { "MO"=>"montags","TU"=>"dienstags","WE"=>"mittwochs","TH"=>"donnerstags","FR"=>"freitags","SA"=>"samstags","SU"=>"sonntags" }
  }.freeze

  ORDINAL_NAMES = {
    de: { 1=>"ersten", 2=>"zweiten", 3=>"dritten", 4=>"vierten", -1=>"letzten", -2=>"vorletzten" },
    en: { 1=>"first", 2=>"second", 3=>"third", 4=>"fourth", -1=>"last", -2=>"second-to-last" }
  }.freeze

  MONTH_NAMES = {
    de: %w[Januar Februar März April Mai Juni Juli August September Oktober November Dezember],
    en: %w[January February March April May June July August September October November December]
  }.freeze

  def humanize_rrule(locale = I18n.locale)
    return nil if rrule.blank?
    parts = Hash[rrule.split(";").map { |p| p.split("=", 2) }]
    return nil if parts["COUNT"] || parts["UNTIL"] # old one-off data, don't guess

    freq, interval, byday, bymonth = parts["FREQ"], parts["INTERVAL"].to_i, parts["BYDAY"], parts["BYMONTH"]
    loc = locale.to_sym
    weekdays = WEEKDAY_NAMES[loc] || WEEKDAY_NAMES[:en]
    ordinals = ORDINAL_NAMES[loc] || ORDINAL_NAMES[:en]
    months   = MONTH_NAMES[loc]   || MONTH_NAMES[:en]

    days = byday&.split(",")&.map do |d|
     if d =~ /^(-?\d+)([A-Z]{2})$/
        "#{ordinals[$1.to_i]} #{weekdays[$2]}"
      else
        weekdays[d]
      end
    end

    base =
      case loc
      when :de
        case freq
        when "WEEKLY"
          if days
            if interval == 2
              adverbial = byday.split(",").map { |d| WEEKDAY_NAMES_ADVERBIAL[:de][d] }
              "Alle zwei Wochen #{adverbial.join(' und ')}"
            else
              "Jeden #{days.join(' und ')}"
            end
          else
            interval == 2 ? "Alle zwei Wochen" : "Wöchentlich"
          end
        when "MONTHLY"
          days ? "Jeden #{days.join(' und ')} im Monat" : "Monatlich"
        end
      else
        case freq
        when "WEEKLY"
          days ? "#{interval == 2 ? 'Every other' : 'Every'} #{days.join(' and ')}" : (interval == 2 ? "Every other week" : "Weekly")
        when "MONTHLY"
          days ? "Every #{days.join(' and ')} of the month" : "Monthly"
        end
      end
    return nil unless base

    if bymonth
      included = bymonth.split(",").map(&:to_i)
      missing = ((1..12).to_a - included)
      if missing.size == 1
        excluded_name = months[missing.first - 1]
        base += (loc == :de ? ", außer im #{excluded_name}" : ", except in #{excluded_name}")
      end
      # more than one missing month: bymonth pattern more complex than we handle, leave base as-is silently
    end

    base
  end
end
