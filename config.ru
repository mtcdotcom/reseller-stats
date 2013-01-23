require 'rubygems'
require 'sinatra/base'
require File.dirname(__FILE__) + "/lib/app"

configure :production do
  require 'newrelic_rpm'
end

port = ENV['PORT'] || 8080
puts port
App.run! :port => port
