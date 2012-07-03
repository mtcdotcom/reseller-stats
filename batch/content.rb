#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'open-uri'

class Content
  def initialize(url)
    @url = url
  end

  def content
    open(@url)
  end

  def euc_content
    content = ""
    open(@url).each {|line|
      content += line.to_s.encode("UTF-8", "EUC-JP", :invalid => :replace, :undef => :replace, :replace => '?')
    }
    content
  end
end
