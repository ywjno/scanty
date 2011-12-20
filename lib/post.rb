$:.unshift File.dirname(__FILE__) + '/../maruku/maruku'
require 'maruku'
$:.unshift File.dirname(__FILE__) + '/../vendor/syntax'
require 'syntax/convertors/html'

class Post < Sequel::Model
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
		end
		create_table
	end

	def url
		d = created_at
		"/#{d.year}/#{d.month}/#{d.day}/#{slug}/"
	end

	def full_url
		Blog.url_base.gsub(/\/$/, '') + url
	end

	def content_html
		to_html(content.to_s)
	end

	def summary
		@summary ||= content.match(/(.{200}.*?\n)/m)
		@summary || content
	end

	def summary_html
		to_html(summary.to_s)
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

	def to_html(markdown)
		out = []
		noncode = []
		code_block = nil
		markdown.split("\n").each do |line|
			if !code_block and line.strip.downcase == '<code>'
				out << Maruku.new(noncode.join("\n")).to_html
				noncode = []
				code_block = []
			elsif code_block and line.strip.downcase == '</code>'
				convertor = Syntax::Convertors::HTML.for_syntax "ruby"
				highlighted = convertor.convert(code_block.join("\n"))
				out << "<code>#{highlighted}</code>"
				code_block = nil
			elsif code_block
				code_block << line
			else
				noncode << line
			end
		end
		out << Maruku.new(noncode.join("\n")).to_html
		out.join("\n")
	end

	def split_content(string)
		parts = string.gsub(/\r/, '').split("\n\n")
		show = []
		hide = []
		parts.each do |part|
			if show.join.length < 100
				show << part
			else
				hide << part
			end
		end
		[ to_html(show.join("\n\n")), hide.size > 0 ]
	end
end
