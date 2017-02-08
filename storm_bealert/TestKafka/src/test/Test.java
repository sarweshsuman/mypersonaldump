package test;

import java.util.Arrays;
import java.util.Collection;
import java.util.Properties;

import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.TopicPartition;

import storm.kafka.KafkaSpout;
import storm.kafka.SpoutConfig;
import storm.kafka.ZkHosts;


public class Test {
	public static void main(String args[]){
		/*
		Properties props = new Properties();
		props.put("bootstrap.servers", "hadoopd01.bc:6667");
		props.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
		props.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
		props.put("group.id", "test");
		props.put("client.id", "test");
		props.put("enable.auto.commit", "true");
		KafkaConsumer<String,String> consumer = new KafkaConsumer<>(props);
		consumer.subscribe(Arrays.asList("osix2"));
		while(true){
			ConsumerRecords<String,String> rec = consumer.poll(1000);
			for(ConsumerRecord record : rec){
				System.out.println(record.value());
			}
		}
		*/
		
	}
}
