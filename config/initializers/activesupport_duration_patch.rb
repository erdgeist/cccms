class Integer
  def days
    ActiveSupport::Duration.new(self * 86400, [[:days, self]])
  end
  alias :day :days

  def weeks
    ActiveSupport::Duration.new(self * 7 * 86400, [[:days, self * 7]])
  end
  alias :week :weeks

  def hours
    ActiveSupport::Duration.new(self * 3600, [[:seconds, self * 3600]])
  end
  alias :hour :hours

  def minutes
    ActiveSupport::Duration.new(self * 60, [[:seconds, self * 60]])
  end
  alias :minute :minutes

  def seconds
    ActiveSupport::Duration.new(self, [[:seconds, self]])
  end
  alias :second :seconds

  def months
    ActiveSupport::Duration.new(self * 30 * 86400, [[:months, self]])
  end
  alias :month :months

  def years
    ActiveSupport::Duration.new((self * 365.25 * 86400).to_i, [[:years, self]])
  end
  alias :year :years
end

class Float
  def days
    ActiveSupport::Duration.new((self * 86400).to_i, [[:days, self]])
  end
  alias :day :days

  def hours
    ActiveSupport::Duration.new((self * 3600).to_i, [[:seconds, (self * 3600).to_i]])
  end
  alias :hour :hours

  def minutes
    ActiveSupport::Duration.new((self * 60).to_i, [[:seconds, (self * 60).to_i]])
  end
  alias :minute :minutes
end
