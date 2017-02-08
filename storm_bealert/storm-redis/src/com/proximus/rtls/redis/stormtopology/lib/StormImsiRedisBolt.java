package com.proximus.rtls.redis.stormtopology.lib;

import java.io.UnsupportedEncodingException;

import backtype.storm.tuple.ITuple;

import org.apache.storm.hdfs.bolt.*;

import backtype.storm.topology.*;

//import org.apache.storm.redis.*;
import org.apache.storm.redis.common.mapper.RedisDataTypeDescription;
import org.apache.storm.redis.common.mapper.RedisStoreMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class StormImsiRedisBolt implements RedisStoreMapper {

	private static final Logger LOG = LoggerFactory.getLogger(StormImsiRedisBolt.class);
    private RedisDataTypeDescription description;
    private final String hashKey = "imsi";

    public StormImsiRedisBolt() {
        description = new RedisDataTypeDescription(
                RedisDataTypeDescription.RedisDataType.HASH, hashKey);
    }

    @Override
    public RedisDataTypeDescription getDataTypeDescription() {
        return description;
    }

    @Override
    public String getKeyFromTuple(ITuple tuple) {
    	LOG.info("Retrieving key from tuple.");
    	LOG.info("The value is "+ String.valueOf(tuple.getValue(0)));
    	String imsi = "";
    	byte[] bytes = tuple.getBinary(tuple.fieldIndex("bytes"));
    	try {
			String osixrec= new String (bytes,"UTF-8");
			LOG.info("The decoded message was "+osixrec);
			String[] value_split = osixrec.split("\\|");
			imsi=value_split[0];
			//The decoded message was IUPS_V12|72108182760662744|2015-08-14 13:47:10.941|206012222176697||9113|||44818|RAU|RAU|||||0|2015-08-14 13:47:13.808|10.42.94.81
		} catch (UnsupportedEncodingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
        return imsi;
    	//return tuple.getStringByField(tuple.getString(0));
    }

    @Override
    public String getValueFromTuple(ITuple tuple) {
    	String cell = "";
    	byte[] bytes = tuple.getBinary(tuple.fieldIndex("bytes"));
    	try {
			String osixrec= new String (bytes,"UTF-8");
			LOG.info("The decoded message was "+osixrec);
			String[] value_split = osixrec.split("\\|");
			cell=value_split[5];
			//The decoded message was IUPS_V12|72108182760662744|2015-08-14 13:47:10.941|206012222176697||9113|||44818|RAU|RAU|||||0|2015-08-14 13:47:13.808|10.42.94.81
		} catch (UnsupportedEncodingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
        return cell;
    }
}