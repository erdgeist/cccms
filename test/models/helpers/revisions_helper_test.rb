require 'test_helper'

class RevisionsHelperTest < ActionView::TestCase
  class RevisionSet
    def initialize revisions
      @revisions = revisions
    end

    def pages
      self
    end

    def exists? conditions
      @revisions.include?(conditions[:revision])
    end
  end

  def node_with *revisions
    RevisionSet.new(revisions)
  end

  test "a forward pair offers both neighbours in forward orientation" do
    assert_equal [[2, 3], [4, 5]],
                 neighbour_revision_pairs(node_with(1, 2, 3, 4, 5), 3, 4)
  end

  test "a reverse pair offers both neighbours in reverse orientation" do
    assert_equal [[3, 2], [5, 4]],
                 neighbour_revision_pairs(node_with(1, 2, 3, 4, 5), 4, 3)
  end

  test "the earliest pair has no earlier neighbour" do
    assert_equal [nil, [2, 3]],
                 neighbour_revision_pairs(node_with(1, 2, 3), 1, 2)
  end

  test "the latest pair has no later neighbour" do
    assert_equal [[1, 2], nil],
                 neighbour_revision_pairs(node_with(1, 2, 3), 2, 3)
  end

  test "a layer comparison offers no neighbours" do
    assert_equal [nil, nil],
                 neighbour_revision_pairs(node_with(1, 2, 3), "head", "draft")
  end

  test "mixing a layer with a number offers no neighbours" do
    assert_equal [nil, nil],
                 neighbour_revision_pairs(node_with(1, 2, 3), "head", 3)
  end

  test "a non-adjacent pair offers no neighbours" do
    assert_equal [nil, nil],
                 neighbour_revision_pairs(node_with(1, 2, 3, 4, 5), 2, 5)
  end

  # The controller sets both ends to 1 when a node has a single page.
  test "a revision compared against itself offers no neighbours" do
    assert_equal [nil, nil], neighbour_revision_pairs(node_with(1), 1, 1)
  end

  test "string references are accepted, since they arrive from the query string" do
    assert_equal [[1, 2], nil],
                 neighbour_revision_pairs(node_with(1, 2, 3), "2", "3")
  end

  # Revision numbers are contiguous today. Should that stop being true, the
  # control disables rather than pointing at a revision that is not there.
  test "a gap disables the control rather than skipping over it" do
    assert_equal [nil, [5, 6]],
                 neighbour_revision_pairs(node_with(1, 2, 4, 5, 6), 4, 5)
  end
end
