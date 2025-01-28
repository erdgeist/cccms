xml.instruct!
xml.tag!("rdf:RDF", "xmlns:rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "xmlns:dc"  => "http://purl.org/dc/elements/1.1/", "xmlns" => "http://purl.org/rss/1.0/") do
  xml.tag!( "rdf:Description",  "rdf:about" => "http://www.w3.org/TR/rdf-syntax-grammar", "dc:title"=>"RDF/XML Syntax Specification (Revised)")

  xml.channel( "rdf:about" => "https://www.ccc.de/de/rss/updates.xml" ) do
    xml.title("Chaos Computer Club: Updates")
    xml.link("https://www.ccc.de")
    xml.description("Kabelsalat ist gesund.")
    xml.tag!("dc:date", @items.first.published_at.xmlschema)
  end

  xml.image( "rdf:about" => "https://www.ccc.de/images/chaosknoten.gif") do
    xml.title("Chaos Computer Club (Chaosknoten)")
    xml.link("https://www.ccc.de")
    xml.url("https://www.ccc.de/images/chaosknoten.gif")
  end

  @items.each do |item|
    xml.item("rdf:about" => content_url(:page_path => item.node.unique_path)) do
      xml.title(item.title)
      xml.link(content_url(:page_path => item.node.unique_path))
      xml.description(item.abstract)
      xml.tag!("dc:creator", (item.user ? item.user.login : "CCC"))
      xml.tag!("dc:date", item.published_at.xmlschema)
    end
  end
end
