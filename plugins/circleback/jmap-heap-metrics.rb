#!/usr/bin/env ruby
#
# JVM Heap Metrics - via Jps/JMap
# ===
#


require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'pp'

class JmapHeapMetric < Sensu::Plugin::Metric::CLI::Graphite

  option :proc,
    :short => '-p PROC_STR',
    :long => '--proc PROC_STR',
    :description => 'Process string to match in JPS',
    :default => nil,
    :required => true

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def jmap(pid)
    out = `jmap -heap #{pid} 2>/dev/null`
    metrics = {}
    keys = %w(eden from to old perm)
    vals = {
      'prcn' => /(\d{0,3}\.\d{0,3})\d*% used/,
      'max'  => /capacity\s+= (\d+)/,
      'used' => /used\s+= (\d+)/,
      'free' => /free\s+= (\d+)/,
    }
    vals.each do |met, rgx|
      out.scan(rgx).flatten.each_with_index do |val, idx|
        key = [keys[idx], met]
        metrics[key] = met == 'prcn' ? val.to_f.round(3) : val
      end
    end
    metrics
  end

  def jps(str)
    out = `jps -ml`
    out.lines.select { |l| l =~ /#{str}/ }.first.split.first
  end

  def run
    timestamp = Time.now.utc.to_i
    metrics = jmap(jps(config[:proc]))
    metrics.each do |keys, value|
      output [config[:scheme], keys].flatten.join("."), value, timestamp
    end

  end

end
