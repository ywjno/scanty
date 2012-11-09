xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title Blog.title
  xml.id Blog.url_base
  xml.updated @posts.first[:created_at].iso8601 if @posts.any?
  xml.author { xml.name Blog.author }

  @posts.each do |post|
    xml.entry do
      xml.title post[:title]
      xml.link "rel" => "alternate", "href" => post.full_url(Blog.url_base)
      xml.id post.full_url(Blog.url_base)
      xml.published post[:created_at].iso8601
      xml.updated post[:created_at].iso8601
      xml.author { xml.name Blog.author }
      xml.summary post.summary_html, "type" => "html"
      xml.content post.content_html, "type" => "html"
    end
  end
end
