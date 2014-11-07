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
require 'win32ole'

class CheckWinServices < Sensu::Plugin::Check::CLI
  WMI = WIN32OLE.connect("winmgmts://")
  GOOD_STATE = "Running"

  option :service ,
    :description  => 'Check services that match regex',
    :long         => '--service SERVICE',
    :short        => '-s SERVICE'

  option :disabled ,
    :description  => 'Ignore disabled services',
    :long         => '--disabled',
    :short        => '-d',
    :boolean      => true,
    :default      => true

  option :manual ,
    :description  => 'Ignore manual services',
    :long         => '--manual',
    :short        => '-m',
    :boolean      => true

  def run
    services = WMI.ExecQuery("Select * from Win32_Service where Name LIKE '%#{config[:service]}%'").each.to_a
    orig_count    = services.count
    services =  services.delete_if { |s| s.StartMode == "Manual" } if config[:manual]
    services =  services.delete_if { |s| s.StartMode == "Disabled" } if config[:disabled]

    states   = services.map { |s| s.State }
    total, good = states.count, states.count { |s| s == GOOD_STATE }

    ok "None running but not expected to run" if (total == 0) && orig_count > 0
    critical "No \"#{config[:service]}\" service(s) found" if total == 0

    message = "#{good} of #{total} \"#{config[:service]}\" service(s) are #{GOOD_STATE}"

    ok       "#{message}" if states.all? { |s| s == GOOD_STATE }
    warning  "#{message}" if states.any? { |s| s == GOOD_STATE }
    critical "#{message}"
  end
end
