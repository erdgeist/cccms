require 'arel'
module Arel
  module Visitors
    [ToSql, DepthFirst].each do |visitor|
      visitor.class_eval do
        def visit_Integer(o, collector = nil)
          collector ? collector << o.to_s : o.to_s
        end
      end
    end
  end
end
