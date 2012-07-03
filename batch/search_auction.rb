#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'cgi'
require 'nokogiri'
require File.dirname(__FILE__) + "/content"

class SearchAuction
  def initialize(keyword)
    @keyword = keyword
  end

  def search
    _results(Content.new(_url))
  end

  def _url
    p = CGI.escape(@keyword.encode("EUC-JP"))
    "http://search.auctions.yahoo.co.jp/search_rss?p=" + p
  end

  def _results(content)
    results = []
    xml = Nokogiri::XML(content.content)
    xml.xpath("//item/link").each {|link|
      results << link.inner_text.split('*')[1]
    }
    results
  end
end
