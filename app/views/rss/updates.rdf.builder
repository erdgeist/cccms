xml.instruct!
xml.tag!("rdf:RDF", "xmlns:rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "xmlns:dc"  => "http://purl.org/dc/elements/1.1/", "xmlns" => "http://purl.org/rss/1.0/") do
  xml.tag!( "rdf:Description",  "rdf:about" => "http://www.w3.org/TR/rdf-syntax-grammar", "dc:title"=>"RDF/XML Syntax Specification (Revised)")

  xml.channel( "rdf:about" => rss_feed_url(:format => "rdf")) do
    xml.title("Chaos Computer Club: Updates")
    xml.link("#{@host}")
    xml.description("Kabelsalat ist gesund.")
    xml.tag!("dc:date", @items.first&.published_at&.xmlschema) if @items.any?
    xml.items do
      xml.tag!("rdf:Seq") do
        @items.each do |item|
          xml.tag!("rdf:li", "rdf:resource" => content_url(:page_path => item.node.unique_path))
        end
      end
    end
    xml.image("rdf:resource" => "#{@host}/images/chaosknoten.gif")
  end

  xml.image( "rdf:about" => "#{@host}/images/chaosknoten.gif") do
    xml.title("Chaos Computer Club (Chaosknoten)")
    xml.link("#{@host}")
    xml.url("#{@host}/images/chaosknoten.gif")
  end

  @items.each do |item|
    xml.item("rdf:about" => content_url(:page_path => item.node.unique_path)) do
      xml.title(item.title.to_s)
      xml.link(content_url(:page_path => item.node.unique_path))
      xml.description(item.abstract.to_s)
      xml.tag!("dc:creator", (item.user ? item.user.login : "CCC"))
      xml.tag!("dc:date", item.published_at.xmlschema)
    end
  end
end
