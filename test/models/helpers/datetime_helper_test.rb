require 'test_helper'

class DatetimeHelperTest < ActionView::TestCase
  test "relative_time_phrase pluralizes correctly in English and German" do
    travel_to Time.zone.parse("2026-07-12 12:00:00") do
      I18n.with_locale(:en) do
        assert_equal "1 day ago", relative_time_phrase(1.day.ago)
        assert_equal "3 days ago", relative_time_phrase(3.days.ago)
      end
      I18n.with_locale(:de) do
        assert_equal "vor 1 Tag", relative_time_phrase(1.day.ago)
        assert_equal "vor 3 Tagen", relative_time_phrase(3.days.ago)
        assert_equal "vor 1 Monat", relative_time_phrase(30.days.ago)
        assert_equal "vor 2 Monaten", relative_time_phrase(45.days.ago)
        assert_equal "vor 2 Jahren", relative_time_phrase(2.years.ago)
      end
    end
  end
end
