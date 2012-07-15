# -*- coding: utf-8 -*-

require 'mongoid'

Mongoid.configure do |config|
  if ENV['MONGOLAB_URI'] then
    /.*:\/\/(.*):(.*).*@(.*):(.*)\/(.*)/ =~ ENV['MONGOLAB_URI']
    con = Mongo::Connection.new($3, $4).db($5)
    con.authenticate($1, $2)
    config.master = con
  else
    config.master = Mongo::Connection.new('localhost', 27017).db("reseller-stats")
  end
end

class Events
  include Mongoid::Document
  field :name
  field :graph_name
  field :keyword, :type => Array
  field :date, :type => Date
  field :place
  field :prefecture
  field :list_price, :type => Array

  embeds_many :auctions
end

class Auction
  include Mongoid::Document
  field :url
  field :seller_id
  field :title
  field :price, :type => Integer
  field :bids, :type => Integer
  field :quantity, :type => Integer
  field :end_time_ut, :type => Integer
  field :complete, :type => Boolean

  embedded_in :events
end

class AuctionStats
  include Mongoid::Document
  field :name
  field :value, :type => Hash

  def execute
    map = %Q{
      function() {
        for (var i = 0; i < this.auctions.length; i ++) {
          if (!this.auctions[i].bids || !this.auctions[i].complete) {
            continue;
          }
          var count = this.auctions[i].quantity;
          var sales = this.auctions[i].price * count;
          emit({name: this.name}, {count: count, sales: sales});
        }
      }
    }
    reduce = %Q{
      function(key, values) {
        var count = 0;
        var sales = 0;
        values.forEach(function(value) {
          count += value.count;
          sales += value.sales;
        });
        return {count: count, sales: sales};
      }
    }
    Events.collection.map_reduce(map, reduce, :out => "auction_stats")
  end
end

class ResellerLists
  include Mongoid::Document
  field :value, :type => Hash

  def execute
    map = %Q{
      function() {
        for (var i = 0; i < this.auctions.length; i ++) {
          if (!this.auctions[i].bids || !this.auctions[i].complete) {
            continue;
          }
          var id    = this.auctions[i].seller_id;
          var count = this.auctions[i].quantity;
          var sales = this.auctions[i].price * count;
          emit(id, {count: count, sales : sales});
        }
      }
    }
    reduce = %Q{
      function(key, values) {
        var count = 0;
        var sales = 0;
        values.forEach(function(value) {
          count += value.count;
          sales += value.sales;
        });
        return {count: count, sales: sales};
      }
    }
    Events.collection.map_reduce(map, reduce, :out => "reseller_lists")
  end
end

class SellerStats
  include Mongoid::Document
  field :value, :type => Hash

  def execute
    map = %Q{
      function() {
        var total = this.value.count;
        if (total > 10) {
          total = 11;
        }
        emit(total, {count: 1});
      }
    }
    reduce = %Q{
      function(key, values) {
        var count = 0;
        values.forEach(function(value) {
          count += value.count;
        });
        return {count: count};
      }
    }
    ResellerLists.collection.map_reduce(map, reduce, :out => "seller_stats")
  end
end

class SalesStats
  include Mongoid::Document
  field :value, :type => Hash

  def execute
    map = %Q{
      function() {
        var sales = this.value.sales;
        if (sales >= 0 && sales <= 49999) {
          emit({sort: 1, range: "0〜49,999"}, {count: 1});
        }
        else if (sales >= 50000 && sales <= 99999) {
          emit({sort: 2, range: "50,000〜99,999"}, {count: 1});
        }
        else if (sales >= 100000 && sales <= 149999) {
          emit({sort: 3, range: "100,000〜149,999"}, {count: 1});
        }
        else if (sales >= 150000 && sales <= 199999) {
          emit({sort: 4, range: "150,000〜199,999"}, {count: 1});
        }
        else if (sales >= 200000 && sales <= 249999) {
          emit({sort: 5, range: "200,000〜249,999"}, {count: 1});
        }
        else if (sales >= 250000 && sales <= 299999) {
          emit({sort: 6, range: "250,000〜299,999"}, {count: 1});
        }
        else if (sales >= 300000 && sales <= 349999) {
          emit({sort: 7, range: "300,000〜349,999"}, {count: 1});
        }
        else if (sales >= 350000 && sales <= 399999) {
          emit({sort: 8, range: "350,000〜399,999"}, {count: 1});
        }
        else if (sales >= 400000 && sales <= 449999) {
          emit({sort: 9, range: "400,000〜449,999"}, {count: 1});
        }
        else if (sales >= 450000 && sales <= 499999) {
          emit({sort: 10, range: "450,000〜499,999"}, {count: 1});
        }
        else if (sales >= 500000) {
          emit({sort: 11, range: "500,000〜"}, {count: 1});
        }
      }
    }
    reduce = %Q{
      function(key, values) {
        var count = 0;
        values.forEach(function(value) {
          count += value.count;
        });
        return {count: count};
      }
    }
    ResellerLists.collection.map_reduce(map, reduce, :out => "sales_stats")
  end
end

class DailyStats
  include Mongoid::Document
  field :name
  field :date
  field :ut, :type => Integer
  field :value, :type => Hash

  def execute
    map = %Q{
      function() {
        for (var i = 0; i < this.auctions.length; i ++) {
          if (!this.auctions[i].bids || !this.auctions[i].complete) {
            continue;
          }
          var date   = new Date();
          var offset = 0;
          offset += date.getTimezoneOffset() * 60000; // MongoLab実行環境の時差
          offset += 3600000 * 9;                      // 東京の時差
          date.setTime(this.auctions[i].end_time_ut * 1000 + offset);
          var y  = date.getFullYear();
          var m  = date.getMonth();
          var d  = date.getDate();
          var ut = new Date(y, m, d);
          var key = {
            name : this.name,
            date : y + "-" + ("0" + (m + 1)).slice(-2) + "-" + ("0" + d).slice(-2),
            ut   : ut.getTime() - offset
          };
          var p = this.auctions[i].price;
          var q = this.auctions[i].quantity;
          emit(key, {count: q, total: p});
        }
      }
    }
    reduce = %Q{
      function(key, values) {
        var count = 0;
        var total = 0;
        values.forEach(function(value) {
          count += value.count;
          total += value.total;
        });
        return {count: count, total: total};
      }
    }
    Events.collection.map_reduce(map, reduce, :out => "daily_stats")
  end
end
