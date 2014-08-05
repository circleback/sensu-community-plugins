#!/usr/bin/env ruby
#
# Solr Cloud Cluster State Health Plugin
# ===
#
# This plugin checks the state of all Solr cores connected to a ZooKeeper cloud.
#
# NOTE: This plugin uses the zk gem and depends on the zookeeper gem which requires building as a native extension.
#
# Copyright 2013 Kyle Burckhard <kyle@marketfish.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'zk'
require 'json'

CRITICAL_STATES = %w{ no_leaders bad_leaders down gone recovery_failed }
WARNING_STATES  = %w{ recovering }
GOOD_STATES     = %w{ active }

class CheckSolrCloudZK < Sensu::Plugin::Check::CLI
  option :zk,
         :description => "ZooKeeper connection string",
         :short => '-z ZK_CS',
         :long => '--zk ZK_CS',
         :require => true

  def zk_connection(zookeeper)
    puts "Connecting to #{zookeeper}" if $DEBUG
    begin
      zk = ZK.new(config[:zk])
    rescue => e
      critical "Exception #{e.class} - #{e.message}"
    end
    return zk
  end

  def process(collections)
    states = {'bad_leaders' => [], 'no_leaders' => []}

    puts "Collections: #{clusterstate.keys.join(' ')}" if $DEBUG
    collections.each do |collection, shards|
      shards.each do |shard, shard_data|
        leader_count = shard_data['replicas'].select {|n, d| d['leader'] == 'true' }
        states['no_leaders'] << "#{collection}-#{shard}" if leader_count.count <= 0

        shard_data['replicas'].each do |name, data|
          states['bad_leaders']  << name if (data['state'] != 'active' && data['leader'] == 'true')
          states[data['state']] ||= Array.new
          states[data['state']] << name
        end
      end
    end
    CRITICAL_STATES.each do |state|
      next unless states.fetch(state) {[]}.count > 0
      critical "#{state.split('_').map {|s| s.capitalize}.join(' ')} Nodes: #{states[state].join(', ')}"
    end

    WARNING_STATES.each do |state|
      next unless states.fetch(state) {[]}.count > 0
      warning "#{state.split('_').map {|s| s.capitalize}.join(' ')} Nodes: #{states[state].join(', ')}"
    end

    unknown_states = states.keys - CRITICAL_STATES - WARNING_STATES - GOOD_STATES
    unknown_states.each do |state|
      critical "Unknown State: #{state}, Nodes: #{states[state].join(', ')}"
    end
  end

  def run
    begin
      zk      = zk_connection(config[:zk])
      json, _ = zk.get('/clusterstate.json')

      process JSON.parse(json)

      zk.close!
      ok
    rescue => e
      critical "Solr ZK check failed: #{e.message}"
    ensure
      zk.close!
    end
  end
end
