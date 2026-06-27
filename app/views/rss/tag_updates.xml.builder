xml.instruct!

xml.feed(:xmlns => "http://www.w3.org/2005/Atom", "xml:base" => @host) do
  xml.title("Chaos Computer Club: #{@tag}")
  xml.link(:href => "#{@host}/")
  xml.link(:rel => "self", :href => "#{@host}/rss/tags/#{@tag}/updates.xml")
  xml.updated(@items.first.published_at.xmlschema) unless @items.empty?
  xml.author do
    xml.name("Chaos Computer Club e. V.")
  end
  xml.id("#{@host}/rss/tags/#{@tag}/updates")

  @items.each do |item|
    xml.entry do
      xml.title(CGI.escapeHTML(item.title.to_s))
      xml.link(
        :href => content_url(:page_path => item.node.unique_path),
        :rel  => "alternate",
        :type => "text/html"
      )
      xml.id(content_url(:page_path => item.node.feed_id))
      xml.updated(item.updated_at.xmlschema)
      xml.published(item.published_at.xmlschema)
      xml.summary(CGI.escapeHTML(item.abstract.to_s))
    end
  end
end
