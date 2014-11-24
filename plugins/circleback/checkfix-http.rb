#!/usr/bin/env ruby
#
# Check HTTP
# ===
#
# Takes either a URL or a combination of host/path/port/ssl, and checks for
# a 200 response (that matches a pattern, if given). Can use client certs.
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
# Updated by Lewis Preson 2012 to accept basic auth credentials
# Updated by SweetSpot 2012 to require specified redirect
# Updated by Chris Armstrong 2013 to accept multiple headers
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'

class CheckFixHTTP < Sensu::Plugin::Check::CLI

  option :url,
    :short => '-u URL',
    :long => '--url URL',
    :description => 'A URL to connect to',
    :default => nil

  option :timeout,
    :short => '-t SECS',
    :long => '--timeout SECS',
    :proc => proc { |a| a.to_i },
    :description => 'Set the timeout (default, 15 sec)',
    :default => 15

  option :insecure,
    :short => '-k',
    :boolean => true,
    :description => 'Enabling insecure connections',
    :default => false

  option :user,
    :short => '-U',
    :long => '--username USER',
    :description => 'A username to connect as'

  option :password,
    :short => '-P PASS',
    :long => '--password PASS',
    :description => 'A password to use for the username'

  option :wait,
    :short => '-w SEC',
    :long => '--wait SEC',
    :proc => proc { |a| a.to_i },
    :description => 'How long to wait before checking the fix (default, 5 sec)',
    :default => 5

  option :attempts,
    :short => '-a TIMES',
    :long => '--attempt TIMES',
    :proc => proc { |a| a.to_i },
    :description => 'Attempt the fix this many times (default, 1 times)',
    :default => 1

  option :cmd,
    :short => '-c CMD',
    :long => '--cmd CMD',
    :description => 'Command to run to attempt fix',
    :default => nil

  option :res_code,
    :short => '-r CODE',
    :long => '--rcode CODE',
    :proc => proc { |a| a.to_i },
    :description => 'HTTP response code to respond to (default, 504)',
    :default => 504

  def run
    unless config[:url]
      unknown 'No URL specified'
    end

    unless config[:cmd]
      unknown 'No fix command specified'
    end

    res = nil
    last_ex = nil

    config[:attempts].times do |attempt|
      begin
        timeout(config[:timeout]) do
          opts = config[:insecure] ? { verify_mode: OpenSSL::SSL::VERIFY_NONE } : {}
          res = RestClient.get(config[:url], opts)
          ok "#{res.code}, #{res.body.size} bytes"
        end
      rescue RestClient::GatewayTimeout, RestClient::ServiceUnavailable  => e
        puts system(config[:cmd])
        last_ex = e
        sleep config[:wait]
      rescue Timeout::Error
        critical "Connection timed out"
      rescue => e
        critical "Connection error: #{e.message}, #{e.class}"
      end
    end

    critical "#{last_ex.message}, Exhausted all attempts to fix issue"
  end

end
