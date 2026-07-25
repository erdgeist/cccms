module RruleHumanizer
  extend ActiveSupport::Concern

  WEEKDAY_NAMES = {
    de: { "MO"=>"Montag","TU"=>"Dienstag","WE"=>"Mittwoch","TH"=>"Donnerstag","FR"=>"Freitag","SA"=>"Samstag","SU"=>"Sonntag" },
    en: { "MO"=>"Monday","TU"=>"Tuesday","WE"=>"Wednesday","TH"=>"Thursday","FR"=>"Friday","SA"=>"Saturday","SU"=>"Sunday" }
  }.freeze

  WEEKDAY_NAMES_ADVERBIAL = {
    de: { "MO"=>"montags","TU"=>"dienstags","WE"=>"mittwochs","TH"=>"donnerstags","FR"=>"freitags","SA"=>"samstags","SU"=>"sonntags" }
  }.freeze

  WEEKDAY_NAMES_ABBR = {
    de: { "MO"=>"Mo","TU"=>"Di","WE"=>"Mi","TH"=>"Do","FR"=>"Fr","SA"=>"Sa","SU"=>"So" },
    :en => { "MO" => "Mon", "TU" => "Tue", "WE" => "Wed", "TH" => "Thu", "FR" => "Fri", "SA" => "Sat", "SU" => "Sun" },
  }.freeze

  ORDINAL_NAMES = {
    de: { 1=>"ersten", 2=>"zweiten", 3=>"dritten", 4=>"vierten", 5=>"fünften", -1=>"letzten", -2=>"vorletzten" },
    en: { 1=>"first", 2=>"second", 3=>"third", 4=>"fourth", 5=>"fifth", -1=>"last", -2=>"second-to-last" }
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

    byday_values = byday&.split(",")
    days = byday_values&.map do |d|
     if d =~ /^(-?\d+)([A-Z]{2})$/
        "#{ordinals[$1.to_i]} #{weekdays[$2]}"
      else
        weekdays[d]
      end
    end

    excluded_monthly_ordinal = nil
    excluded_monthly_weekday = nil
    selected_monthly_ordinals = nil
    selected_monthly_weekday = nil
    if freq == "MONTHLY" && byday_values.present?
      ordinal_days = byday_values.map { |d| d.match(/^([1-5])([A-Z]{2})$/) }
      if ordinal_days.all?
        positions = ordinal_days.map { |match| match[1].to_i }.uniq.sort
        weekdays_in_rule = ordinal_days.map { |match| match[2] }.uniq
        if weekdays_in_rule.size == 1
          selected_monthly_ordinals = positions
          selected_monthly_weekday = weekdays_in_rule.first
          missing_positions = (1..5).to_a - positions
          if positions.size == 4 && missing_positions.size == 1
            excluded_monthly_ordinal = missing_positions.first
            excluded_monthly_weekday = selected_monthly_weekday
          end
        end
      end
    end

    join_ordinals = lambda do |ordinal_values, conjunction|
      names = ordinal_values.map { |ordinal| ordinals[ordinal] }
      names.size > 1 ? "#{names[0..-2].join(', ')} #{conjunction} #{names.last}" : names.first
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
          if excluded_monthly_ordinal
            "Jeden #{weekdays[excluded_monthly_weekday]} im Monat, außer dem #{ordinals[excluded_monthly_ordinal]} #{weekdays[excluded_monthly_weekday]}"
          elsif selected_monthly_ordinals
            "Jeden #{join_ordinals.call(selected_monthly_ordinals, 'und')} #{weekdays[selected_monthly_weekday]} im Monat"
          else
            days ? "Jeden #{days.join(' und ')} im Monat" : "Monatlich"
          end
        end
      else
        case freq
        when "WEEKLY"
          days ? "#{interval == 2 ? 'Every other' : 'Every'} #{days.join(' and ')}" : (interval == 2 ? "Every other week" : "Weekly")
        when "MONTHLY"
          if excluded_monthly_ordinal
            "Every #{weekdays[excluded_monthly_weekday]} of the month, except the #{ordinals[excluded_monthly_ordinal]} #{weekdays[excluded_monthly_weekday]}"
          elsif selected_monthly_ordinals
            "Every #{join_ordinals.call(selected_monthly_ordinals, 'and')} #{weekdays[selected_monthly_weekday]} of the month"
          else
            days ? "Every #{days.join(' and ')} of the month" : "Monthly"
          end
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

  def self.wday_abbr(time, locale)
    code = %w[SU MO TU WE TH FR SA][time.wday]
    (WEEKDAY_NAMES_ABBR[locale.to_sym] || WEEKDAY_NAMES_ABBR[:de])[code]
  end
end
