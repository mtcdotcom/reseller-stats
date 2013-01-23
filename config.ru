require 'rubygems'
require 'sinatra/base'
require File.dirname(__FILE__) + "/lib/app"

port = ENV['PORT'] || 8080
puts port
App.run! :port => port