# encoding: utf-8

require 'rubygems'
require 'sinatra/base'
require 'sinatra/contrib'
require 'sequel'
require 'builder'
require 'digest/sha1'

class Main < Sinatra::Base
  register Sinatra::Contrib

  config_file "#{settings.root}/config.yml"

  configure do
    DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://blog.db')

    require 'ostruct'
    Blog = OpenStruct.new(
      :title => settings.title,
      :subtitle => settings.subtitle,
      :author => settings.author,
      :url_base => settings.url_base,
      :admin_password => Digest::SHA1.hexdigest(settings.admin_password),
      :admin_cookie_key => settings.admin_cookie_key,
      :admin_cookie_value => Digest::SHA1.hexdigest(settings.admin_cookie_value),
      :disqus_shortname => settings.disqus_shortname ||= nil,
      :page_size => settings.page_size.to_i,
      :timezone => settings.timezone
    )
  end

  configure :development do
    register Sinatra::Reloader
  end

  error do
    e = request.env['sinatra.error']
    puts e.to_s
    puts e.backtrace.join("\n")
    "Application error"
  end

  $LOAD_PATH.unshift("#{settings.root}/lib")
  require 'post'

  helpers do
    def admin?
      request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
    end

    def auth
      halt [ 401, 'Not authorized' ] unless admin?
    end

    def paginate(post, options={})
      return "" if post.page_count == 1
      html = '<div class="paginate">'
      url = ""
      url = "/tags/#{options[:tag]}" if options[:tag]
      if post.prev_page
        html += "<p class=\"pull-left\"><a href=\"#{url}/page/#{post.prev_page}\">&larr;&nbsp;Previous</a></p>"
      end
      if post.next_page
        html += "<p class=\"pull-right\"><a href=\"#{url}/page/#{post.next_page}\">Next&nbsp;&rarr;</a></p>"
      end
      html += "</div>"
    end
  end

  ### Public

  get '/' do
    posts = Post.filter(:delete_status => 1).reverse_order(:created_at).paginate(1, Blog.page_size)
    erb :index, :locals => { :posts => posts, :dates => Post.dates(admin?) }, :layout => :sidebar_layout
  end

  get %r{^/\d{4}/\d{2}/\d{2}/(?<slug>[a-zA-Z0-9%\-]+)/?$} do
    posts = nil
    if admin?
      post = Post.filter(:slug => URI.escape(params[:slug])).first
    else
      post = Post.filter(:delete_status => 1).filter(:slug => URI.escape(params[:slug])).first
    end
    halt [ 404, "Page not found" ] unless post
    erb :post, :locals => { :post => post }, :layout => :layout
  end

  get '/archive' do
    posts = nil
    if admin?
      posts = Post.reverse_order(:created_at)
    else
      posts = Post.filter(:delete_status => 1).reverse_order(:created_at)
    end
    erb :archive, :locals => { :posts => posts }, :layout => :layout
  end

  get '/tags/:tag' do
    tag = params[:tag]
    posts = Post.filter(:delete_status => 1).filter(:tags.like("%#{tag}%")).reverse_order(:created_at).paginate(1, Blog.page_size)
    erb :tagged, :locals => { :posts => posts, :tag => tag }, :layout => :layout
  end

  get '/page/:page' do
    posts = Post.filter(:delete_status => 1).reverse_order(:created_at).paginate(params[:page].to_i, Blog.page_size)
    redirect '/' if posts.page_count < params[:page].to_i
    erb :index, :locals => { :posts => posts, :dates => Post.dates(admin?) }, :layout => :sidebar_layout
  end

  get '/tags/:tag/page/:page' do
    tag = params[:tag]
    posts = Post.filter(:delete_status => 1).filter(:tags.like("%#{tag}%")).reverse_order(:created_at).paginate(params[:page].to_i, Blog.page_size)
    redirect '/' if posts.page_count < params[:page].to_i
    erb :tagged, :locals => { :posts => posts, :tag => tag }, :layout => :layout
  end

  get %r{/(?:rss|feed)(?:.xml)?} do
    @posts = Post.filter(:delete_status => 1).reverse_order(:created_at).limit(20)
    content_type 'application/atom+xml', :charset => 'utf-8'
    builder :feed
  end

  get %r{^/(?<year>\d{4})/(?<month>\d{2})/?$} do
    all_posts = nil
    if admin?
      all_posts = Post.reverse_order(:created_at)
    else
      all_posts = Post.filter(:delete_status => 1).reverse_order(:created_at)
    end

    posts = []
    all_posts.each do |post|
      posts << post if post.created_at.strftime("%Y") == params[:year] and post.created_at.strftime("%m") == params[:month]
    end

    erb :archive, :locals => { :posts => posts }, :layout => :layout
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
    post = nil
    DB.transaction do
      post = Post.new(
              :title => params[:title],
              :tags => params[:tags],
              :content => params[:content],
              :format => params[:format],
              :created_at => Time.now.utc.getlocal(Blog.timezone))
      post.save
    end
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
    delete_status = params[:delete_status] ? 0 : 1
    post = nil
    DB.transaction do
      post = Post.filter(:slug => URI.escape(params[:slug])).first
      halt [ 404, "Page not found" ] unless post
      unless params[:delete_status]
        post.title = params[:title]
        post.tags = params[:tags]
        post.content = params[:content]
        post.slug = Post.make_slug(params[:title]) if params[:change_slug]
        post.format = params[:format]
      end
      post.delete_status = delete_status
      post.update

      if params[:delete_status]
        redirect '/'
      else
        redirect post.url
      end
    end
  end

  run! if app_file == $0
end
