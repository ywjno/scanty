# encoding: utf-8

require 'rdiscount'
require 'redcloth'

class Post < Sequel::Model
  include Rack::Utils
  alias_method :h, :escape_html

  Sequel.extension :pagination
  plugin :schema

  unless table_exists?
    set_schema do
      primary_key :id
      text :title, :null=>false
      text :content, :null=>false
      text :slug, :null=>false
      text :tags, :null=>false
      timestamp :created_at, :null=>false
      Integer :delete_status, :null=>false, :default=> 1
      text :format, :null=>false, :default=> "txt"
    end
    create_table
  end

  def url
    "/#{created_at.strftime('%Y/%m/%d')}/#{slug}/"
  end

  def full_url
    Blog.url_base.gsub(/\/$/, '') + url
  end

  def content_html
    to_html(content.to_s, format)
  end

  def summary
    @summary ||= content.match(/(.{200}.*?\n)/m)
    @summary || content
  end

  def summary_html
    to_html(summary.to_s, format)
  end

  def more?
    @more ||= content.match(/.{200}.*?\n(.*)/m)
    @more
  end

  def linked_tags
    tags.split.inject([]) do |accum, tag|
      accum << "<a href=\"/tags/#{tag}\">#{tag}</a>"
    end.join(" ")
  end

  def self.make_slug(title)
    slug = URI.escape(title.downcase.gsub(/[ _]/, '-')).gsub(/[^a-zA-Z0-9%\-]/, '').squeeze('-')
    unless Post.filter(:slug => slug).first
      slug
    else
      count = Post.filter(:slug.like("#{slug}-%")).count + 1
      "#{slug}-#{(count + 1)}"
    end
  end

  def delete?
    delete_status == 0
  end

  def self.dates(admin)
    dates = {}
    posts = nil
    if admin
      posts = Post.reverse_order(:created_at)
    else
      posts = Post.filter(:delete_status => 1).reverse_order(:created_at)
    end
    posts.each do |post|
      dates[post.created_at.strftime("%Y/%m")] = post.created_at.strftime("%Y-%m") unless dates[post.created_at.strftime("%Y/%m")]
    end
    dates
  end

  def show_create_at
    created_at.strftime("%Y-%m-%d %H:%M:%S")
  end

  ########

  def to_html(content, format = 'txt')
    return case format
      when 'markdown'
        RDiscount.new(content).to_html
      when 'textile'
        RedCloth.new(content).to_html
      else
        split_content(content)
      end
  end

  def split_content(string)
    show_html = ""
    p_content = []
    lines = string.split("\n")
    lines.each_with_index do |line, index|
      new_line = h(line.strip)
      if index != lines.length - 1
        unless new_line.empty?
          p_content << new_line
        else
          show_html += "<p>#{p_content.join('<br />')}</p>"
          p_content = []
        end
      else
        if p_content.length != 0
          p_content << new_line
          show_html += "<p>#{p_content.join("<br />")}</p>"
        else
          show_html += "<p>#{new_line}</p>"
        end
      end
    end
    show_html
  end

end
