require 'rubygems'
require 'rspec'
require 'sequel'
require 'rack/test'

Sequel.sqlite

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'post'

require 'ostruct'
Blog = OpenStruct.new(
  :title => 'My blog',
  :author => 'Anonymous Coward',
  :url_base => 'http://blog.example.com/'
)
