package com.proximus.rtls.redis.stormtopology.main;

import backtype.storm.Config;
import backtype.storm.StormSubmitter;
import backtype.storm.generated.AlreadyAliveException;
import backtype.storm.generated.AuthorizationException;
import backtype.storm.generated.InvalidTopologyException;
import backtype.storm.topology.TopologyBuilder;

import org.apache.storm.redis.bolt.AbstractRedisBolt;
import org.apache.storm.redis.bolt.RedisStoreBolt;
import org.apache.storm.redis.common.config.JedisPoolConfig;
import org.apache.storm.redis.common.mapper.RedisStoreMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import storm.kafka.KafkaSpout;
import storm.kafka.SpoutConfig;
import storm.kafka.ZkHosts;

import java.io.FileInputStream;
import java.io.Serializable;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Arrays;
import java.util.Properties;

import com.proximus.rtls.redis.stormtopology.lib.*;

/**
 * Created by Sarwesh on 09.05.16.
 */

public class TopologyMain{
	private static final Logger LOG = LoggerFactory.getLogger(TopologyMain.class);	
    public static void main(String[] args) throws AlreadyAliveException, InvalidTopologyException {

    	if (args.length > 0) {
            System.out.println("Got args: " + Arrays.toString(args));
        } else {
            System.out.println("No Args specified. Please specify a properties file");
            System.exit(255);
        }

        String propfilename = args[0]; // this should be a properties file
        Properties props = new Properties();

        try {
            TopologyBuilder tb = new TopologyBuilder();
            FileInputStream infle = new FileInputStream(propfilename);
            props.load(infle);

            // check for a few properties we do absolutely need
            // The kafka part in the config
            String kafka_topic = props.getProperty("kafka.topic");
            String kafka_zookeeper_consumer_offset_path = props.getProperty("kafka.zookeeper.consumer.offset.path", "/osixkafka");
            String kafka_zookeeper_consumer_offset_id = props.getProperty("kafka.zookeeper.consumer.offset.id", "discovery");
            String broker_hosts = props.getProperty("broker.hosts", "localhost:2181");
            String storm_topology_name = props.getProperty("storm.topology.name", "osix_kafka");
            String kafka_spout_name = props.getProperty("kafka.spout.name", "kafkareader");
            String hdfs_bolt_name = props.getProperty("storm.bolt.name", "redisbolt");

            //redis configuration
            String redis_host= props.getProperty("redis.host", "localhost");
            int redis_port= Integer.parseInt(props.getProperty("redis.port", "localhost"));
            String Redisbolt = props.getProperty("storm.bolt","RedisWriteBolt");
            int database = Integer.parseInt(props.getProperty("redis.database", "0"));
            int expire = Integer.parseInt(props.getProperty("redis.imsi.expire","14400"));
            
            
            System.out.println("kafka_topic " + kafka_topic);
            // Set up the kafka configuration
            SpoutConfig spc = new SpoutConfig(new ZkHosts(broker_hosts)
                    , kafka_topic // topic
                    , kafka_zookeeper_consumer_offset_path      // root path in zookeeper for the spout to store consumer offsets
                    , kafka_zookeeper_consumer_offset_id   // id for storing consumer offsets in zookeeper
            );
            //spc.stateUpdateIntervalMs=1000;
            KafkaSpout kfksp = new KafkaSpout(spc);
            tb.setSpout(kafka_spout_name, kfksp);
            // Set up redis configuration
            JedisPoolConfig poolConfig = new JedisPoolConfig.Builder()
                    .setHost(redis_host).setPort(redis_port).setDatabase(database).build();
            // First bolt was for POC, do not switch to this bolt in production
            if (Redisbolt.equalsIgnoreCase("RedisWriteBolt")){
            	RedisStoreMapper ImsiWriteBolt = new StormImsiRedisBolt();
            	RedisStoreBolt storeBolt = new RedisStoreBolt(poolConfig, ImsiWriteBolt);
            	tb.setBolt(hdfs_bolt_name,storeBolt).shuffleGrouping(kafka_spout_name);
            }
            else if (Redisbolt.equalsIgnoreCase("RedisImsiCustomBolt")){
            	AbstractRedisBolt ImsiReadWriteBolt = new RedisImsiCustomBolt(poolConfig,expire);
            	tb.setBolt(hdfs_bolt_name,ImsiReadWriteBolt).shuffleGrouping(kafka_spout_name);
            }
            else if (Redisbolt.equalsIgnoreCase("PipedBolt")){
            	PipedBolt pipedbolt = new PipedBolt(redis_host,redis_port,database,expire);
            	tb.setBolt(hdfs_bolt_name, pipedbolt).shuffleGrouping(kafka_spout_name);
            }
            //
            Config conf = new Config(); // this is a config that should contain the deployment crap

            try {
                StormSubmitter.submitTopology(storm_topology_name, conf, tb.createTopology());
            } catch (AuthorizationException e) {
                e.printStackTrace();
            }

        } catch (FileNotFoundException e) {
            System.out.println("The specified file " + propfilename + " does not exist");
            System.exit(255);
        } catch (IOException e) {
            System.out.println("An IO Exception Occurred: " + e.getMessage());
            System.exit(255);
        }
    }
}