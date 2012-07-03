#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'nokogiri'
require File.dirname(__FILE__) + "/content"

class ParseAuction
  def initialize(url)
    @url = url
  end

  def parse
    @html = Nokogiri::HTML(Content.new(@url).euc_content)
    {
      :is_ticket   => _is_ticket?,
      :url         => @url,
      :seller_id   => _seller_id,
      :title       => _title,
      :price       => _price,
      :bids        => _bids,
      :quantity    => _quantity,
      :end_time_ut => _end_time_ut
    }
  end

  def _is_ticket?
    @html.css("meta").each {|attr|
      attr.values.each {|value|
        if value == "keywords"
          re = Regexp.new('<meta name="keywords" content="(.*)">')
          m  = re.match(attr.to_s)
          if /.*チケット.*/u =~ m[1]
            return true
          end
        end
      }
    }
    false
  end

  def _seller_id
    _attribute("div.pts01 table tr td b", "auction:SellerID")
  end

  def _title
    _attribute("div.decBg04 table tr td h1", "auction:Title")
  end

  def _price
    price = _attribute("div.pts03 table tr td p", "auction:Price")
    if price == 0
      price = _attribute("div.pts03 table tr td p", "auction:BidOrBuyPrice")
    end
    price == 0 ? 0 : price.gsub(/,| |円/, '')
  end

  def _bids
    _attribute("div.pts03 table tr td b", "auction:Bids")
  end

  def _quantity
    _attribute("div.pts04 table tr td", "auction:Quantity")
  end

  def _end_time_ut
    _attribute("div.pts04 span", "auction:EndTimeUT")
  end

  def _attribute(tag, id)
    @html.css(tag).each {|attr|
      attr.values.each {|value|
        return attr.inner_text if (value == id);
      }
    }
  end
end
