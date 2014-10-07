#!/usr/bin/env ruby
#
# This is metrics which outputs the CPU load in Graphite acceptable format.
# To get the cpu stats for Windows Server to send over to Graphite.
# It basically uses the typeperf to get the processor usage at a given particular time.
#
# Copyright 2013 <jashishtech@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
# rubocop:disable VariableName, MethodName
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'pp'

class TypePerfMetric < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def get_matrics_hash(metrics)
    metric = metrics.values.map {|m| %Q("#{m}")}.join(' ')
    lookup = {}
    metrics.each do |k, v|
      lookup[v.split("\\").last] = k
    end
    tempArr   = []

    command   = %Q(typeperf -sc 1 #{metric})
    IO.popen(command) { |io| io.each { |line| tempArr.push(line) } }

    keys  = tempArr[1].split(",")[1..-1].map {|n| n.strip[1..-2].split("\\").last }
    names = keys.map {|k| lookup[k] || k.downcase.gsub(' ', '_')}
    stats = tempArr[2].split(",")[1..-1].map {|s| sprintf "%.2f", s[1..-3].to_f	}
    Hash[names.zip(stats)]
  end

  def flat_hash(h, f = [], g = {})
    return g.update({ f=>h }) unless h.is_a? Hash
    h.each { |k, r| flat_hash(r, f+[k], g) }
    g
  end

  def run
    timestamp = Time.now.utc.to_i

    metrics = {}

    metrics[:disk] = get_matrics_hash({
      c_free_mb:    		'\LogicalDisk(c:)\Free Megabytes',
      c_avg_queue:  		'\LogicalDisk(c:)\Avg. Disk Queue Length',
      c_avg_read_queue: 	'\LogicalDisk(c:)\Avg. Disk Read Queue Length',
      c_avg_write_queue:	'\LogicalDisk(c:)\Avg. Disk Write Queue Length',
      c_read_bps:			'\PhysicalDisk(*C:)\Disk Read Bytes/sec',
      c_write_bps:		'\PhysicalDisk(*C:)\Disk Write Bytes/sec',
      c_idle_time:		'\PhysicalDisk(*C:)\% Idle Time'
    })

    metrics[:cpu] = get_matrics_hash({
      processor_prc: '\Processor(_Total)\% Processor Time',
      user_prc:      '\Processor(_Total)\% User Time',
      priv_prc:      '\Processor(_Total)\% Privileged Time',
      idle_prc:      '\Processor(_Total)\% Idle Time',
      interrupt_prc: '\Processor(_Total)\% Interrupt Time',
      interrupts_ps: '\Processor(_Total)\Interrupts/sec',
    })

    metrics[:system] = get_matrics_hash({
      threads: '\System\Threads',
      uptime:  '\System\System Up Time',
      q_len:   '\System\Processor Queue Length',
      procs:   '\System\Processes'
    })

    metrics[:network] = get_matrics_hash({
      in_bps: '\Network Interface(*NIC*)\Bytes Received/sec',
      out_bps: '\Network Interface(*NIC*)\Bytes Sent/sec',
      out_qlen:  '\Network Interface(*NIC*)\Output Queue Length'
    })

    metrics[:memory] = get_matrics_hash({
      pf_usage:   '\Paging File(_Total)\% Usage',
      faults_ps:  '\Memory\Page Faults/sec',
      avail_byte: '\Memory\Available Bytes',
      commt_byte: '\Memory\Committed Bytes'
    })

    flat_hash(metrics).each do |keys, value|
      output [config[:scheme], keys].flatten.join("."), value, timestamp
    end
    ok
  end
end
