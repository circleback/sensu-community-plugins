#!/usr/bin/env ruby
#
# Postgres Stat BGWriter Metrics
# ===
#
# Dependencies
# -----------
# - Ruby gem `pg`
#
#
# Copyright 2012 Kwarter, Inc <platforms@kwarter.com>
# Author Gilles Devaux <gilles.devaux@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/metric/cli'
require 'pg'
require 'socket'

class PostgresStatsDBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :user,
         description: 'Postgres User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'Postgres Password',
         short: '-p PASS',
         long: '--password PASS'

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST',
         default: 'localhost'

  option :port,
         description: 'Database port',
         short: '-P PORT',
         long: '--port PORT',
         default: 5432

  option :scheme,
         description: 'Metric naming scheme, text to prepend to $queue_name.$metric',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.postgresql"

  def run
    timestamp = Time.now.to_i

    con     = PG::Connection.new(config[:hostname], config[:port], nil, nil, 'postgres', config[:user], config[:password])
    request = [
      'select checkpoints_timed, checkpoints_req,',
      'buffers_checkpoint, buffers_clean,',
      'maxwritten_clean, buffers_backend,',
      'buffers_alloc',
      'from pg_stat_bgwriter'
    ]
    con.exec(request.join(' ')) do |result|
      result.each do |row|
        output "#{config[:scheme]}.bgwriter.checkpoints_timed", row['checkpoints_timed'], timestamp
        output "#{config[:scheme]}.bgwriter.checkpoints_req", row['checkpoints_req'], timestamp
        output "#{config[:scheme]}.bgwriter.buffers_checkpoint", row['buffers_checkpoint'], timestamp
        output "#{config[:scheme]}.bgwriter.buffers_clean", row['buffers_clean'], timestamp
        output "#{config[:scheme]}.bgwriter.maxwritten_clean", row['maxwritten_clean'], timestamp
        output "#{config[:scheme]}.bgwriter.buffers_backend", row['buffers_backend'], timestamp
        output "#{config[:scheme]}.bgwriter.buffers_alloc", row['buffers_alloc'], timestamp
      end
    end

    ok
  end
end
