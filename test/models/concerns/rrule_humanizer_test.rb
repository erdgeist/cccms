require 'test_helper'

class RruleHumanizerTest < ActiveSupport::TestCase
  def humanize(rrule, locale = :de)
    Event.new(rrule: rrule).humanize_rrule(locale)
  end

  test "weekly single day" do
    assert_equal "Jeden Dienstag", humanize("FREQ=WEEKLY;BYDAY=TU")
    assert_equal "Every Tuesday", humanize("FREQ=WEEKLY;BYDAY=TU", :en)
  end

  test "weekly two days" do
    assert_equal "Jeden Mittwoch und Freitag", humanize("FREQ=WEEKLY;BYDAY=WE,FR")
    assert_equal "Every Wednesday and Friday", humanize("FREQ=WEEKLY;BYDAY=WE,FR", :en)
  end

  test "weekly no byday" do
    assert_equal "Wöchentlich", humanize("FREQ=WEEKLY")
    assert_equal "Weekly", humanize("FREQ=WEEKLY", :en)
  end

  test "biweekly with day" do
    assert_equal "Alle zwei Wochen donnerstags", humanize("FREQ=WEEKLY;INTERVAL=2;BYDAY=TH")
    assert_equal "Every other Thursday", humanize("FREQ=WEEKLY;INTERVAL=2;BYDAY=TH", :en)
  end

  test "biweekly no day" do
    assert_equal "Alle zwei Wochen", humanize("FREQ=WEEKLY;INTERVAL=2")
    assert_equal "Every other week", humanize("FREQ=WEEKLY;INTERVAL=2", :en)
  end

  test "monthly nth weekday" do
    assert_equal "Jeden ersten Dienstag im Monat", humanize("FREQ=MONTHLY;BYDAY=1TU")
    assert_equal "Jeden zweiten Freitag im Monat", humanize("FREQ=MONTHLY;BYDAY=2FR")
    assert_equal "Jeden dritten Sonntag im Monat", humanize("FREQ=MONTHLY;BYDAY=3SU")
    assert_equal "Jeden letzten Mittwoch im Monat", humanize("FREQ=MONTHLY;BYDAY=-1WE")
  end

  test "monthly nth weekday english" do
    assert_equal "Every first Tuesday of the month", humanize("FREQ=MONTHLY;BYDAY=1TU", :en)
    assert_equal "Every last Wednesday of the month", humanize("FREQ=MONTHLY;BYDAY=-1WE", :en)
  end

  test "monthly second-to-last" do
    assert_equal "Jeden vorletzten Donnerstag im Monat", humanize("FREQ=MONTHLY;BYDAY=-2TH")
    assert_equal "Every second-to-last Thursday of the month", humanize("FREQ=MONTHLY;BYDAY=-2TH", :en)
  end

  test "monthly no byday" do
    assert_equal "Monatlich", humanize("FREQ=MONTHLY")
    assert_equal "Monthly", humanize("FREQ=MONTHLY", :en)
  end

  test "monthly with single excluded month" do
    assert_equal "Jeden letzten Donnerstag im Monat, außer im Dezember",
      humanize("FREQ=MONTHLY;BYDAY=-1TH;BYMONTH=1,2,3,4,5,6,7,8,9,10,11")
    assert_equal "Every last Thursday of the month, except in December",
      humanize("FREQ=MONTHLY;BYDAY=-1TH;BYMONTH=1,2,3,4,5,6,7,8,9,10,11", :en)
  end

  test "monthly excluding january" do
    assert_equal "Jeden zweiten Mittwoch im Monat, außer im Januar",
      humanize("FREQ=MONTHLY;BYMONTH=2,3,4,5,6,7,8,9,10,11,12;BYDAY=2WE")
  end

  test "blank rrule returns nil" do
    assert_nil humanize(nil)
    assert_nil humanize("")
  end

  test "count and until are not guessed at" do
    assert_nil humanize("FREQ=MONTHLY;BYDAY=1WE;COUNT=36")
    assert_nil humanize("FREQ=MONTHLY;BYDAY=1WE;UNTIL=20050105T222222Z")
  end

  test "unrecognized freq returns nil" do
    assert_nil humanize("FREQ=YEARLY;BYMONTH=12")
  end

  test "falls back to english for unknown locale" do
    assert_equal "Every Tuesday", humanize("FREQ=WEEKLY;BYDAY=TU", :fr)
  end
end
