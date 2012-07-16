# -*- coding: utf-8 -*-

require 'rubygems'
require 'erb'
require File.dirname(__FILE__) + "/db"

class App < Sinatra::Base
  set :static, true
  set :public, 'public'

  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    username = ENV['BASIC_AUTH_USERNAME']
    password = ENV['BASIC_AUTH_PASSWORD']
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [username, password]
  end

  get '/' do
    protected!
    total  = _total
    events = _events(_auction_stats())
    erb :index, :locals => {
                            :events      => events,
                            :total_count => _currency_fmt(total[:count].to_i),
                            :total_sales => _currency_fmt(total[:sales].to_i)
                           }
  end

  def _total
    count = 0
    sales = 0
    AuctionStats.all.each {|as|
      count += as.value["count"].to_i
      sales += as.value["sales"].to_i
    }
    {
      :count => count,
      :sales => sales
    }
  end

  def _auction_stats()
    count = {}
    sales = {}
    AuctionStats.all.each {|at|
      count.store(at._id["name"].to_s, at.value["count"].to_i)
      sales.store(at._id["name"].to_s, at.value["sales"].to_i)
    }
    {
      :count => count,
      :sales => sales
    }
  end

  def _events(stats)
    events = []
    Events.all.order_by(:date.desc).each {|e|
      count = stats[:count][e.name] ? stats[:count][e.name] : 0
      sales = stats[:sales][e.name] ? stats[:sales][e.name] : 0
      events << {
        :id         => e._id.to_s,
        :name       => e.name,
        :date       => e.date,
        :list_price => _fmt_list_price(e.list_price),
        :keyword    => e.keyword,
        :count      => count,
        :sales      => _currency_fmt(sales)
      }
    }
    events
  end

  def _fmt_list_price(list_price)
    list_prices = []
    list_price.each {|lp|
      list_prices << {
        "type"  => lp["type"],
        "price" => _currency_fmt(lp["price"].to_i)
      }
    }
    list_prices
  end

  get '/detail' do
    event       = nil
    name        = ""
    daily_stats = []
    price_stats = []
    auctions    = []
    begin
      event = Events.find(params[:id])
    rescue => e
      puts e
      puts $@
    end
    if event
      name        = event.name
      daily_stats = _daily_stats(name)
      price_stats = _price_stats(name)
      auctions    = _detail_list(event)
    end
    erb :detail, :locals => {
                             :name        => name,
                             :daily_stats => daily_stats,
                             :price_stats => price_stats,
                             :auctions    => auctions
                            }
  end

  def _daily_stats(name)
    stats = []
    DailyStats.where("_id.name" => name).order_by(["_id.ut", :asc]).each {|t|
      stats << {
        :ut    => t._id["ut"].to_i,
        :count => t.value["count"].to_i,
        :total => t.value["total"].to_i
      }
    }
    stats
  end

  def _price_stats(name)
    stats = []
    total = 0
    PriceStats.where("_id.name" => name).order_by(["_id.sort", :asc]).each {|ps|
      count = ps.value["count"].to_i
      key   = ps._id["range"].to_s + " 円"
      stats << {
        :key   => key,
        :count => count
      }
      total += count
    }
    {
      :stats => stats,
      :total => total
    }
  end

  def _detail_list(event)
    auctions = []
    event.auctions.where(
                         :complete => true,
                         :bids.gt  => 0).order_by(
                                                  [[:price,       :desc],
                                                   [:bids,        :asc],
                                                   [:end_time_ut, :asc]]).each {|auction|
      auctions << {
        :title       => auction.title,
        :url         => auction.url,
        :is_ticket   => auction.is_ticket,
        :price       => _currency_fmt(auction.price),
        :bids        => auction.bids,
        :quantity    => auction.quantity,
        :seller_id   => auction.seller_id,
        :end_time_ut => _datetime_fmt(auction.end_time_ut.to_i)
      }
    }
    auctions
  end

  get '/reseller' do
    total       = _total
    reseller    = _reseller()
    other_count = total[:count] - reseller[:total_count]
    other_sales = total[:sales] - reseller[:total_sales]
    erb :reseller, :locals => {
                               :total_count => _currency_fmt(total[:count].to_i),
                               :total_sales => _currency_fmt(total[:sales].to_i),
                               :other_count => other_count,
                               :other_sales => other_sales,
                               :reseller    => reseller[:reseller],
                               :reseller_count     => reseller[:total_count],
                               :reseller_sales     => reseller[:total_sales],
                               :reseller_count_fmt => _currency_fmt(reseller[:total_count]),
                               :reseller_sales_fmt => _currency_fmt(reseller[:total_sales])
                              }
  end

  def _reseller()
    reseller = []
    total_count = 0
    total_sales = 0
    ResellerLists.all(:limit => 50).order_by(["value.sales", :desc]).each {|rl|
      count = rl.value["count"].to_i
      sales = rl.value["sales"].to_i
      total_count += count
      total_sales += sales
      reseller << {
        :id    => rl._id.to_s,
        :count => count,
        :sales => _currency_fmt(sales),
      }
    }
    {
      :reseller    => reseller,
      :total_count => total_count,
      :total_sales => total_sales
    }
  end

  get '/stats' do
    erb :stats, :locals => {
                            :seller_stats => _seller_stats,
                            :sales_stats  => _sales_stats
                           }
  end

  def _seller_stats()
    stats = []
    total = 0
    SellerStats.all.order_by(["_id", :asc]).each {|ss|
      count = ss.value["count"].to_i
      key   = ss._id.to_i > 10 ? "11 件以上" : ss._id.to_i.to_s + " 件"
      stats << {
        :key   => key,
        :count => count
      }
      total += count
    }
    {
      :stats => stats,
      :total => total
    }
  end

  def _sales_stats()
    stats = []
    total = 0
    SalesStats.all.order_by(["_id.sort", :asc]).each {|ss|
      count = ss.value["count"].to_i
      key   = ss._id["range"].to_s + " 円"
      stats << {
        :key   => key,
        :count => count
      }
      total += count
    }
    {
      :stats => stats,
      :total => total
    }
  end

  def _mask_id(id)
    id[0..2] + "*****"
  end

  def _currency_fmt(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  def _datetime_fmt(ut)
    Time.at(ut).strftime("%Y-%m-%d %H:%M:%S")
  end

  get '/about' do
    erb :about, :locals => {}
  end
end
