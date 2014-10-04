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
    tempArr   = []

    command   = %Q(typeperf -sc 1 #{metric})
    IO.popen(command) { |io| io.each { |line| tempArr.push(line) } }

	names = tempArr[1].split(",")[1..-1].map {|n| metrics.invert[n.match(/(\\Process.+)/)[1][0..-2]] }
    stats = tempArr[2].split(",")[1..-1].map {|s| sprintf "%.2f",s[1..-3].to_f	}
    Hash[names.zip(stats)]
  end

  def get_processes(matcher)
    tempArr   = []

    command   = %Q(typeperf -sc 1 "\\Process(#{matcher})\\ID Process")
    IO.popen(command) { |io| io.each { |line| tempArr.push(line) } }

    tempArr[1].split(",")[1..-1].map{ |s| s.match(/Process\((.+)\)/)[1] }
  end

  def flat_hash(h,f=[],g={})
	return g.update({ f=>h }) unless h.is_a? Hash
	h.each { |k,r| flat_hash(r,f+[k],g) }
	g
  end
  def run
    timestamp = Time.now.utc.to_i
	processes = get_processes("DubLabs.*.Api*")

    metrics = {
		"api_srv_count" => processes.size
    }

	processes.each_with_index do |name, idx|
		metrics["api_srv_#{idx}"] = get_matrics_hash({
			pid:			"\\Process(#{name})\\ID Process",
			proc_prc: 		"\\Process(#{name})\\% Processor Time",
			user_prc: 		"\\Process(#{name})\\% User Time",
			priv_prc: 		"\\Process(#{name})\\% Privileged Time",
			pg_faults_ps: 	"\\Process(#{name})\\Page Faults/sec",
			thrd_cnt: 		"\\Process(#{name})\\Thread Count",
			uptime: 		"\\Process(#{name})\\Elapsed Time",
			handles: 		"\\Process(#{name})\\Handle Count",
			io_read_bps: 	"\\Process(#{name})\\IO Read Bytes/sec",
			io_write_bps: 	"\\Process(#{name})\\IO Write Bytes/sec",
			io_data_bps: 	"\\Process(#{name})\\IO Data Bytes/sec",
			io_other_bps: 	"\\Process(#{name})\\IO Other Bytes/sec"
		})
	end

    flat_hash(metrics).each do |keys, value|
		output [config[:scheme], keys].flatten.join("."), value, timestamp
    end
    ok
  end
end
