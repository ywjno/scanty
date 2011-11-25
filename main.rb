require 'rubygems'
require 'sinatra'
require 'digest/sha1'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/vendor/sequel'
require 'sequel'

configure do
	DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://blog.db')

	DB.create_table? :posts do
		primary_key :id
		text :title, :null=>false
		text :content, :null=>false
		text :slug, :null=>false
		text :tags, :null=>false
		timestamp :created_at, :null=>false
	end

	require 'ostruct'
	Blog = OpenStruct.new(
		:title => 'a scanty blog',
		:subtitle => 'Scanty, a really small blog',
		:author => 'John Doe',
		:url_base => 'http://localhost:4567/',
		:admin_password => Digest::SHA1.hexdigest('changeme'),
		:admin_cookie_key => 'scanty_admin',
		:admin_cookie_value => Digest::SHA1.hexdigest('51d6d976913ace58'),
		:disqus_shortname => nil,
		:page_size => 10
	)
end

error do
	e = request.env['sinatra.error']
	puts e.to_s
	puts e.backtrace.join("\n")
	"Application error"
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'

helpers do
	def admin?
		request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
	end

	def auth
		halt [ 401, 'Not authorized' ] unless admin?
	end

	def paginate(post, options={})
		html = ""
		url = ""
		url = "/tags/#{options[:tag]}" if options[:tag]
		if post.prev_page
			html += "<p class=\"pull-left\"><a href=\"#{url}/page/#{post.prev_page}\">&larr;&nbsp;Previous</a></p>"
		end
		if post.next_page
			html += "<p class=\"pull-right\" style=\"margin-left: 120px;\"><a href=\"#{url}/page/#{post.next_page}\">Next&nbsp;&rarr;</a></p>"
		end
		html
	end
end

### Public

get '/' do
	posts = Post.reverse_order(:created_at).paginate(1, Blog.page_size)
	erb :index, :locals => { :posts => posts }, :layout => :sidebar_layout
end

get %r{^/\d{4}/\d{2}/\d{2}/(?<slug>[a-zA-Z0-9%\-]+)/?$} do
	puts params[:slug]
	post = Post.filter(:slug => URI.escape(params[:slug])).first
	halt [ 404, "Page not found" ] unless post
	erb :post, :locals => { :post => post }, :layout => :layout
end

get '/archive' do
	posts = Post.reverse_order(:created_at)
	erb :archive, :locals => { :posts => posts }, :layout => :layout
end

get '/tags/:tag' do
	tag = params[:tag]
	posts = Post.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).paginate(1, Blog.page_size)
	erb :tagged, :locals => { :posts => posts, :tag => tag }, :layout => false
end

get '/page/:page' do
	posts = Post.reverse_order(:created_at).paginate(params[:page].to_i, Blog.page_size)
	redirect '/' if posts.page_count < params[:page].to_i
	erb :index, :locals => { :posts => posts }, :layout => :sidebar_layout
end

get '/tags/:tag/page/:page' do
	tag = params[:tag]
	posts = Post.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).paginate(params[:page].to_i, Blog.page_size)
	redirect '/' if posts.page_count < params[:page].to_i
	erb :tagged, :locals => { :posts => posts, :tag => tag }, :layout => false
end

get '/feed' do
	@posts = Post.reverse_order(:created_at).limit(20)
	content_type 'application/atom+xml', :charset => 'utf-8'
	builder :feed
end

get '/rss' do
	redirect '/feed', 301
end

### Admin

get '/auth' do
	erb :auth, :locals => { :error => false }
end

post '/auth' do
	if Digest::SHA1.hexdigest(params[:password]) == Blog.admin_password
		response.set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value)
		redirect '/'
	else
		erb :auth, :locals => { :error => true }
	end
end

get '/logout' do
	response.delete_cookie(Blog.admin_cookie_key)
	redirect '/'
end

get '/posts/new' do
	auth
	erb :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
	auth
	post = Post.new :title => params[:title], :tags => params[:tags], :content => params[:content], :created_at => Time.now, :slug => Post.make_slug(params[:title])
	post.save
	redirect post.url
end

get %r{^/\d{4}/\d{2}/\d{2}/(?<slug>[a-zA-Z0-9%\-]+)/edit/?$} do
	auth
	post = Post.filter(:slug => URI.escape(params[:slug])).first
	halt [ 404, "Page not found" ] unless post
	erb :edit, :locals => { :post => post, :url => post.url }
end

post %r{^/\d{4}/\d{2}/\d{2}/(?<slug>[a-zA-Z0-9%\-]+)/$} do
	auth
	post = Post.filter(:slug => URI.escape(params[:slug])).first
	halt [ 404, "Page not found" ] unless post
	post.title = params[:title]
	post.tags = params[:tags]
	post.content = params[:content]
	post.save
	redirect post.url
end

