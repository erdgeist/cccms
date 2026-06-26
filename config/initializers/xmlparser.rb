class XML::Node
  def replace_with(other)
    self.next = other
    remove!
  end
end

# Builder 3.x escapes content by default. Override _escape to pass text
# through raw, preserving existing behaviour from the Rails 2 era.
# Note: require builder first to ensure XmlBase < BasicObject is already
# defined before we reopen it.
require 'builder'
module Builder
  class XmlBase
    def _escape(text)
      text
    end
  end
end
