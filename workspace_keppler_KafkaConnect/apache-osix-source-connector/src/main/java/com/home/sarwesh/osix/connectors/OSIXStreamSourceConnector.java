package com.home.sarwesh.osix.connectors;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.common.config.ConfigDef.Importance;
import org.apache.kafka.common.config.ConfigDef.Type;
import org.apache.kafka.common.utils.AppInfoParser;
import org.apache.kafka.connect.connector.Task;
import org.apache.kafka.connect.errors.ConnectException;
import org.apache.kafka.connect.source.SourceConnector;


/*
 *  For Learning purpose this connector will only read data from a kafka topic
 */
public class OSIXStreamSourceConnector extends SourceConnector {
	public static final String SOURCE_TOPIC_CONFIG = "source.topic";
	public static final String DESTINATION_TOPIC_CONFIG = "destination.topic";
	private static final ConfigDef CONFIG_DEF = new ConfigDef().define(SOURCE_TOPIC_CONFIG,Type.STRING, Importance.HIGH, "Source topic from where data to read").define(DESTINATION_TOPIC_CONFIG, Type.STRING, Importance.HIGH, "Destination topic to write to");

	private String src_topic;
	private String dst_topic;

	@Override
	public String version(){
		return AppInfoParser.getVersion();
	}
	@Override
	public void start(Map<String,String> props){
		src_topic = props.get(SOURCE_TOPIC_CONFIG);
		if ( src_topic == null || src_topic.isEmpty())
			throw new ConnectException("OSIXStreamSourceConnector confiruation must include 'source.topic' setting ");
		dst_topic = props.get(DESTINATION_TOPIC_CONFIG);
			throw new ConnectException("OSIXStreamSourceConnector confiruation must include 'destination.topic' setting ");
	}
	@Override
	public List<Map<String,String>> taskConfigs(int maxTasks){
        ArrayList<Map<String, String>> configs = new ArrayList<Map<String,String>>();
        // For now we will read from one topic with one partition hence one task only.
        Map<String, String> config = new HashMap<String,String>();
        config.put(SOURCE_TOPIC_CONFIG, src_topic);
        config.put(DESTINATION_TOPIC_CONFIG, dst_topic);
        configs.add(config);
        return configs;
	}
	@Override
	public void stop(){

	}
	@Override
	public ConfigDef config(){
		return CONFIG_DEF;
	}
    @Override
    public Class<? extends Task> taskClass() {
        return OSIXStreamSourceTask.class;
    }
}
