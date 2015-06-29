#!/usr/bin/env ruby
#
# Pulls numeric values out of a JSON return and pushes them into Graphite
# ===
#
# DESCRIPTION:
#   Pulls numeric values out of a JSON return and pushes them into Graphite
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   rest-client Ruby gem
#
# Copyright 2012 Marketfish, Inc <kyle@marketfish.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'
require 'pp'

module Enumerable
  def flatten_with_path(parent_prefix = nil)
    res = {}

    self.each_with_index do |elem, i|
      if elem.is_a?(Array)
        k, v = elem
      else
        k, v = i, elem
      end

      key = parent_prefix ? "#{parent_prefix}.#{k}" : k # assign key name for result hash

      if v.is_a? Enumerable
        res.merge!(v.flatten_with_path(key)) # recursive call to flatten child elements
      else
        res[key] = v
      end
    end

    res
  end
end

class JSON2Graphite < Sensu::Plugin::Metric::CLI::Graphite
  option :url,
    :short => "-u URL",
    :long => "--url URL",
    :description => "URL to get",
    :required => true

  option :object_path,
    :short => "-o PATH",
    :long => "--obj PATH",
    :description => "Path to the numeric in the JSON return, recordsPerSecond/total",
    :default => nil

  option :ignore,
    :short => "-i PATH",
    :long => "--ignore PATH",
    :description => "String to match keys that should be ignored",
    :default => "asd70a9sd70hn13n1le709a7d9asdnkaldnio123981739183yhnlkasnjd9asd7a0"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.ws"

  def get_url_json(url)
    begin
      r = RestClient::Resource.new(url, :timeout => 45)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    end
  end

  def fetch(hsh, path)
    return hsh if path.nil? || path == ''
    path.split('/').inject(hsh) do |location, key|
      location.respond_to?(:keys) ? location[key] : nil
    end
  end

  def underscore(camel_cased_word)
    camel_cased_word.gsub(/::/, '_').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def run
    json_hash = get_url_json(config[:url])
    json_hash = fetch(json_hash, config[:object_path]) if config[:object_path]
    json_hash = json_hash.flatten_with_path(config[:scheme])
    
    json_hash.each do |metric, value|
      metric_name = underscore(metric)
      if config[:ignore] && !(metric_name =~ /#{Regexp.quote(config[:ignore])}/i)
        output metric_name, value.to_i if value.kind_of?(Numeric)
      end
    end
    ok
  end

end
