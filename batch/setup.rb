#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + "/../lib/db"
require File.dirname(__FILE__) + "/search_auction"
require File.dirname(__FILE__) + "/parse_auction"

class Setup
  def execute
    today = DateTime.now.strftime("%Y-%m-%d")
    Events.where(:date.gte => today).order_by(:date.asc).each {|event|
      SearchAuction.new(event.keyword.join(' ')).search.each {|link|
        auction = event.auctions.where({url: link}).first
        unless auction
          event.auctions << Auction.new(
                                        :url      => link,
                                        :complete => false
                                        )
        end
      }
      event.save
    }
    Events.all.each {|event|
      event.auctions.where(complete: false).each {|auction|
        begin
          parse = ParseAuction.new(auction.url).parse
          auction.seller_id   = parse[:seller_id]
          auction.title       = parse[:title]
          auction.price       = parse[:price]
          auction.bids        = parse[:bids]
          auction.quantity    = parse[:quantity]
          auction.end_time_ut = parse[:end_time_ut]
          auction.is_ticket   = parse[:is_ticket]
          # 取り消しオークション対応(終了時刻+αでオークション終了とみなす)
          if Time.now.to_i >= (parse[:end_time_ut].to_i + (0.1 * 86400))
             auction.complete = true
          end
          # キーワードに"チケット"が入っていないオークションを除外
          unless parse[:is_ticket]
            auction.complete = true
            auction.bids     = 0
          end
        rescue => e
          # 取り消しオークション対応(取り消しされるとログイン認証を求められるらしい)
          if /^redirection forbidden:*/ =~ e.to_s
            auction.complete = true
            auction.bids     = 0
          else
            puts $@
            puts e.backtrace
          end
        end
      }
      event.save
    }
  end
end

Setup.new.execute
AuctionStats.new.execute
ResellerLists.new.execute
SellerStats.new.execute
SalesStats.new.execute
DailyStats.new.execute
PriceStats.new.execute
