require 'diff/lcs'
require 'cgi'

module HtmlWordDiff
  TOKEN_REGEXP = /<[^>]*>|[[:space:]]+|[[:alnum:]]+|[^[:space:][:alnum:]<>]/

  def self.inline(old_html, new_html)
    html = +''
    each_change(old_html, new_html) do |action, old_token, new_token|
      case action
      when '='
        html << new_token
      when '-'
        html << wrap_removed(old_token)
      when '+'
        html << wrap_inserted(new_token)
      when '!'
        html << wrap_removed(old_token)
        html << wrap_inserted(new_token)
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
        old_out << wrap_removed(old_token)
      when '+'
        new_out << wrap_inserted(new_token)
      when '!'
        old_out << wrap_removed(old_token)
        new_out << wrap_inserted(new_token)
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
    html.to_s.gsub(/\r\n?/, "\n").scan(TOKEN_REGEXP)
  end

  def self.tag_token?(token)
    token.to_s.match?(/\A<[^>]*>\z/)
  end

  def self.wrap_removed(token)
    if tag_token?(token)
      %(<del class="diff_structural" title="removed: #{CGI.escapeHTML(token)}">\u00b6</del>)
    else
      "<del>#{token}</del>"
    end
  end

  def self.wrap_inserted(token)
    if tag_token?(token)
      %(<ins class="diff_structural" title="added: #{CGI.escapeHTML(token)}">\u00b6</ins>)
    else
      "<ins>#{token}</ins>"
    end
  end
end
