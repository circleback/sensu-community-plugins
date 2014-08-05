#!/usr/bin/env ruby
#
# Push Apache Solr stats into graphite
# ===
#
# TODO: Flags to narrow down needed stats only
#
# Copyright 2013 Kyle Burckhard <kyle@marketfish.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

## http://solrcloud01.prod.marketfish.com:8983/solr/filterservice/select?q=*%3A*&rows=0&wt=json&distrib=false

class CheckSolrQuery < Sensu::Plugin::Check::CLI
  option :url,
         :description => "Solr Query URL",
         :short => '-u URL',
         :long => '--url URL',
         :require => true

  def get_url_json(url)
    begin
      r = RestClient::Resource.new(url, timeout: 45)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    rescue RestClient::ResourceNotFound
      warning "404 resource not found - #{url}"
    rescue => e
      warning "RestClient exception: #{e.class} -> #{e.message}"
    end
  end

  def run
    begin
        resp = get_url_json(config[:url])
        critical "Solr query status not 0" if resp['responseHeader']['status'] != 0
        ok
    rescue => e
      warning "Check failed due to exception: #{e.class} - #{e.message}"
    end
  end

end
