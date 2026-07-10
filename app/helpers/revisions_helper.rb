module RevisionsHelper
  # Human-readable label for a diff endpoint -- "head"/"draft"/"autosave"
  # get their name; anything else is a revision number.
  def describe_page_reference(ref)
    %w[head draft autosave].include?(ref.to_s) ? ref.to_s.capitalize : "revision #{ref}"
  end
end
