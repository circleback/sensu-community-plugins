#!/usr/bin/env ruby
#
# Push Redis INFO stats into graphite
# ===
#
# Copyright 2012 Pete Shima <me@peteshima.com>
#                Brian Racer <bracer@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'redis'

class RedisKey2Graphite < Sensu::Plugin::Metric::CLI::Graphite

  # redis.c - sds genRedisInfoString(char *section)

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Redis Host to connect to",
    :default => 'localhost'

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Redis Port to connect to",
    :proc => proc {|p| p.to_i },
    :default => '6379'

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.redis"

  option :key,
    :short  => "-k KEY",
    :long   => "--key KEY",
    :description => "Optional, redis key to run command against",
    :required => false

  option :command,
    :short        => "-c COMMAND",
    :long         => "--cmd COMMAND",
    :description  => "Redis command used to generate metric",
    :proc => proc {|c| c.downcase },
    :required => true

  def run
    redis = Redis.new(:host => config[:host], :port => config[:port])
    cmd_sym = config[:command].to_sym

    critical "Redis does not appear to accept command" unless redis.respond_to? cmd_sym

    if key = config[:key]
      result = redis.send(cmd_sym, key)
      output "#{config[:scheme]}.#{key}.#{cmd_sym.to_s}", result
    else
      result = redis.send(cmd_sym)
      output "#{config[:scheme]}.#{cmd_sym.to_s}", result
    end

    ok
  end
end
