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
require 'ruby-wmi'

class CheckWinServices < Sensu::Plugin::Check::CLI

  GOOD_STATE = "Running"

  option :service ,
    :description  => 'Check services that match regex',
    :long         => '--service SERVICE',
    :short        => '-s SERVICE'

  option :disabled ,
    :description  => 'Ignore disabled services',
    :long         => '--disabled',
    :short        => '-d',
    :boolean      => true

  option :manual ,
    :description  => 'Ignore manual services',
    :long         => '--manual',
    :short        => '-m',
    :boolean      => true

  def run
    services =  WMI::Win32_Service.all.select {|s| s.name =~ /#{config[:service]}/i }
    services =  services.delete_if {|s| s.start_mode = "Manual" } if config[:manual]
    services =  services.delete_if {|s| s.start_mode = "Disabled" } if config[:disabled]

    states   = services.map { |s| s.state }
    total, good = states.count, states.count {|s| s == GOOD_STATE}
    critical "No \"#{config[:service]}\" service(s) found" if total == 0

    message = "#{good} of #{total} \"#{config[:service]}\" service(s) are #{STATES[GOOD_STATE]}"

    ok       "#{message}" if states.all? {|s| s == GOOD_STATE}
    warning  "#{message}" if states.any? {|s| s == GOOD_STATE}
    critical "#{message}"
  end
end
