#!/usr/bin/env ruby
#
# Check Named Windows Service Plugin
# This plugin checks whether services matching the User-inputted string are
# running or not.
#
# This checks service control (sc.exe) tool to find any service on Windows is
# running or not.
#
# Copyright 2014 <kyle.burckhard@circleback.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckWinServices < Sensu::Plugin::Check::CLI

  GOOD_STATE = 4
  STATES = {
    1 => "STOPPED",
    2 => "START_PENDING",
    3 => "STOP_PENDING",
    4 => "RUNNING",
    5 => "CONTINUE_PENDING",
    6 => "PAUSE_PENDING",
    7 => "PAUSED"
  }

  option :service ,
    :description => 'Check services that match regex',
    :long => '--service SERVICE',
    :short => '-s SERVICE'

  def parse_list(scv_list, srv_hash = {})
    scv_list.split(/^$/).map {|b| b.strip}.each do |srv|
      tmp_hash = {}
      srv.split("\n").map {|l| l.strip}.each do |line|
        tmp = line.split(":").map {|v| v.strip }
        tmp_hash[tmp[0]] = tmp[1]
      end
      srv_hash[tmp_hash["SERVICE_NAME"]] = tmp_hash
    end

    srv_hash
  end

  def run
    scv = parse_list(IO.popen("sc query type= service state= all").read)
    states = scv.select {|k, v| k =~ /#{config[:service]}/i }.map {|k, h| h["STATE"].to_i }

    total, good = states.count, states.count {|s| s == GOOD_STATE}
    critical "No \"#{config[:service]}\" service(s) found" if total == 0

    message = "#{good} of #{total} \"#{config[:service]}\" service(s) are #{STATES[GOOD_STATE]}"

    ok       "#{message}" if states.all? {|s| s == GOOD_STATE}
    warning  "#{message}" if states.any? {|s| s == GOOD_STATE}
    critical "#{message}"
  end
end
