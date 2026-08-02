module RevisionsHelper
  # Human-readable label for a diff endpoint -- "head"/"draft"/"autosave"
  # get their name; anything else is a revision number.
  def describe_page_reference(ref)
    %w[head draft autosave].include?(ref.to_s) ? ref.to_s.capitalize : "revision #{ref}"
  end

  def neighbour_revision_pairs node, start_ref, end_ref
    return [nil, nil] unless start_ref.to_s.match?(/\A\d+\z/) &&
                             end_ref.to_s.match?(/\A\d+\z/)

    a, b = start_ref.to_i, end_ref.to_i
    return [nil, nil] unless (a - b).abs == 1

    lo, hi  = [a, b].minmax
    forward = a < b
    earlier = forward ? [lo - 1, lo] : [lo, lo - 1]
    later   = forward ? [hi, hi + 1] : [hi + 1, hi]

    [earlier, later].map do |pair|
      pair if pair.all? { |rev| node.pages.exists?(:revision => rev) }
    end
  end
end
