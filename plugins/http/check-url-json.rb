#!/usr/bin/env ruby
#
# Checks ElasticSearch cluster status
# ===
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch cluster status, using its API.
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
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class UrlJsonStringStatus < Sensu::Plugin::Check::CLI
  option :url,
    :short => "-u URL",
    :long => "--url URL",
    :description => "URL to get",
    :required => true

option :object_path,
    :short => "-o OBJ",
    :long => "--obj OBJ",
    :description => "Path to the numeric in the JSON return, recordsPerSecond/total",
    :required => true

  option :warning,
    :short => "-w STR",
    :long => "--warn STR",
    :description => "String if the status is warning",
    :required => false

  option :critical,
    :short => "-c STR",
    :long => "--crit STR",
    :description => "String if the status is critical",
    :required => false

   option :good,
    :short => "-g STR",
    :long => "--g STR",
    :description => "String if the status is good",
    :required => false


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
    return hsh if path.nil?
    path.split('/').inject(hsh) do |location, key|
      location.respond_to?(:keys) ? location[key] : nil
    end
  end

  def run
    if [config[:good], config[:warning], config[:critical]].none?
      warning "Need at least 1 Good, Warning or Critical string"
    end
    json_hash = get_url_json(config[:url])
    result = fetch(json_hash, config[:object_path])
    result =~ /#{Regexp.quote(config[:good])}/

    if config[:critical] && result =~ /#{Regexp.quote(config[:critical])}/i
      critical "Check returned critical result, #{result}"
    end

    if config[:warning] && result =~ /#{Regexp.quote(config[:warning])}/i
      warning "Check returned warning result, #{result}"
    end

    if config[:good] && result =~ /#{Regexp.quote(config[:good])}/i
      ok "Check returned good result, #{result}"
    else
      critical "Check did not return a good result"
    end
  end

end
