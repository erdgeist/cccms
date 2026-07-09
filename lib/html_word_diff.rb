require 'diff/lcs'

module HtmlWordDiff
  TOKEN_REGEXP = /<[^>]*>|[[:space:]]+|[[:alnum:]]+|[^[:space:][:alnum:]<>]/

  def self.inline(old_html, new_html)
    html = +''
    each_change(old_html, new_html) do |action, old_token, new_token|
      case action
      when '='
        html << new_token
      when '-'
        html << "<del>#{old_token}</del>"
      when '+'
        html << "<ins>#{new_token}</ins>"
      when '!'
        html << "<del>#{old_token}</del><ins>#{new_token}</ins>"
      end
    end
    html
  end

  def self.side_by_side(old_html, new_html)
    old_out = +''
    new_out = +''
    each_change(old_html, new_html) do |action, old_token, new_token|
      case action
      when '='
        old_out << old_token
        new_out << new_token
      when '-'
        old_out << "<del>#{old_token}</del>"
      when '+'
        new_out << "<ins>#{new_token}</ins>"
      when '!'
        old_out << "<del>#{old_token}</del>"
        new_out << "<ins>#{new_token}</ins>"
      end
    end
    [old_out, new_out]
  end

  def self.each_change(old_html, new_html)
    Diff::LCS.sdiff(tokenize(old_html), tokenize(new_html)).each do |change|
      yield change.action, change.old_element, change.new_element
    end
  end

  def self.tokenize(html)
    html.to_s.scan(TOKEN_REGEXP)
  end
end
