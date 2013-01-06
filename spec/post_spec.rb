require File.dirname(__FILE__) + '/base'

describe Post do
  before do
    @post = Post.new
  end

  it "has a url in simplelog format: /past/2008/10/17/my_post/" do
    @post.created_at = '2008-10-22'
    @post.slug = "my-post"
    @post.url.should == '/2008/10/22/my-post/'
  end

  it "has a full url including the Blog.url_base" do
    @post.created_at = '2008-10-22'
    @post.slug = "my-post"
    Blog.stub!(:url_base).and_return('http://blog.example.com/')
    @post.full_url(Blog.url_base).should == 'http://blog.example.com/2008/10/22/my-post/'
  end

  it "produces html from the markdown body" do
    @post.content = "* Bullet"
    @post.format = "markdown"
    @post.content_html.should == "<ul>\n  <li>Bullet</li>\n</ul>\n"
  end

  it "makes the tags into links to the tag search" do
    @post.tags = "one two"
    @post.linked_tags.should == '<a href="/tags/one">one</a> <a href="/tags/two">two</a>'
  end

  it "can save itself (primary key is set up)" do
    Blog.stub!(:timezone).and_return('+08:00')
    @post.title = 'hello'
    @post.content = 'world'
    @post.tags = 'test'
    @post.created_at = Time.now.utc.getlocal(Blog.timezone)
    @post.save
    Post.filter(:title => 'hello').first.content.should == 'world'
  end

  it "generates a slug from the title (but saved to db on first pass so that url never changes)" do
    @post.title = "RestClient 0.8"
    @post.make_slug.should == 'restclient-08'
    @post.title = "Rushmate, rush + TextMate"
    @post.make_slug.should == 'rushmate-rush-textmate'
    @post.title = "Object-Oriented File Manipulation"
    @post.make_slug.should == 'object-oriented-file-manipulation'
  end

  it "produces html from the textile body" do
    @post.content = "* Bullet"
    @post.format = "textile"
    @post.content_html.should == "<ul>\n\t<li>Bullet</li>\n</ul>"
  end

  it "produces html from the txt body" do
    @post.content = "one\ntwo\nthree"
    @post.format = "txt"
    @post.content_html.should == "<p>one<br />two<br />three</p>"
  end
end
