require 'timeout'

a = Node.root.children.create!(:slug => "cycle_test_a")
b = a.children.create!(:slug => "cycle_test_b")

a.staged_parent_id = b.id
a.publish_draft!
a.reload

puts "a.parent_id after staging a under its own child b: #{a.parent_id.inspect} (b.id = #{b.id})"
puts "Node.valid? => #{Node.valid?}"

begin
  Timeout.timeout(3) { puts "a.level => #{a.level}" }
rescue Timeout::Error
  puts "TIMED OUT after 3s -- a real cycle and a real infinite loop, confirmed"
end

# Break any cycle before cleanup -- delete_descendants does its own BFS
# the same way #level does, and would hang on a real cycle too.
Node.where(id: a.id).update_all(parent_id: nil)
b.destroy
a.destroy
