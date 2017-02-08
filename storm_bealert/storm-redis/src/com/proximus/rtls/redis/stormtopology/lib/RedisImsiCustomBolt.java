package com.proximus.rtls.redis.stormtopology.lib;


import java.io.UnsupportedEncodingException;
import java.util.HashMap;
import java.util.Map;

import org.apache.storm.redis.bolt.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.apache.storm.redis.common.config.JedisPoolConfig;
import org.apache.storm.redis.common.config.JedisClusterConfig;

import redis.clients.jedis.JedisCommands;
import backtype.storm.topology.OutputFieldsDeclarer;
import backtype.storm.tuple.Fields;
import backtype.storm.tuple.Tuple;


public class RedisImsiCustomBolt extends AbstractRedisBolt {
	private static final Logger LOG = LoggerFactory.getLogger(RedisImsiCustomBolt.class);
	private ImsiMessage imsimsg;
	int expireInterval;
	public RedisImsiCustomBolt(JedisPoolConfig config,int expire) {
        super(config);
		this.expireInterval=expire;        
    }

    public RedisImsiCustomBolt(JedisClusterConfig config,int expire) {
        super(config);
    	this.expireInterval=expire;        
    }

    /**
     * Bolt is executed for each record (tuple) coming from kafka
     *
     * @param  tuple  storm tuple coming from kafka. Be careful , this is binary data
     */
    @Override
    public void execute(Tuple input) {
    	JedisCommands jedisCommands = null;
    	byte[] bytes = input.getBinary(input.fieldIndex("bytes"));
    	//decode the byte string and create an ImsiMessage object
    	try {
			String osixrec= new String (bytes,"UTF-8");
			this.imsimsg=new ImsiMessage(osixrec);
			if ( this.imsimsg.getInterfacetype().equalsIgnoreCase("GB_V7") && this.imsimsg.getTransactiontype().equalsIgnoreCase("RAU") && this.imsimsg.getTransactionsubtype().equalsIgnoreCase("RAU")){			
				this.collector.ack(input);
				return;				
			}
		} catch (UnsupportedEncodingException e) {
			// TODO Auto-generated catch block
			//LOG.debug("Received exception " + e.getMessage());
			//e.printStackTrace();
			this.collector.ack(input);
			return;
		}
    	try{
    		jedisCommands = getInstance();
    		String imsi = this.imsimsg.getImsi();
    		//retrieve the cell,lac value for a key. if cell exists then the key exists. Direct key checking not possible
    		String cell=jedisCommands.hget("imsi:"+imsi, "cell");
    		String lac=jedisCommands.hget("imsi:"+imsi, "lac");
    		
    		//LOG.debug("Checking if key is in redis or not for key:"+String.valueOf(this.imsimsg.getImsi()));
    		
    		if (cell!=null){
    			Map<String, String> properties = jedisCommands.hgetAll("imsi:" + imsi);
    			ImsiMessage storedimsi= new ImsiMessage(imsi,properties);
    			if (storedimsi.getNetworkEventDate().isBefore(this.imsimsg.getNetworkEventDate())){
    				//LOG.debug("NEw data is newer than the old date");
    				jedisCommands.hset("imsi:" + imsi, "cell", String.valueOf(this.imsimsg.getCell()));
    				jedisCommands.hset("imsi:" + imsi, "lac", String.valueOf(this.imsimsg.getLac()));
    				jedisCommands.hset("imsi:" + imsi, "network_event_ts", String.valueOf(this.imsimsg.getNetwork_event_ts()));
    				int imei = this.imsimsg.getImei();
    				if(imei != 0){
    					jedisCommands.hset("imsi:" + imsi, "imei", String.valueOf(imei));
    				}
    				
    				jedisCommands.expire("imsi:" + imsi, this.expireInterval);
    				
    				jedisCommands.expire("imsitomsisdn:" + imsi, this.expireInterval);
    				
    				//LOG.debug("Existing record with newer data. We need to update cell imsi relation");
    				Boolean cell_found=jedisCommands.exists("cell:"+cell+":"+lac);

    				if (cell_found){
        				//LOG.debug("Cell was found, removing the imsi from this cell");
        				jedisCommands.lrem("cell:"+cell+":"+lac, 0, imsi);        				    					
    				}
    				jedisCommands.lpush("cell:" + String.valueOf(this.imsimsg.getCell()) + ":"+ String.valueOf(this.imsimsg.getLac()), imsi);
    				
    				/*
    				if (cell_found){
        				jedisCommands.lpush("cell:" + String.valueOf(this.imsimsg.getCell()), String.valueOf(this.imsimsg.getImsi()));
        			}
        			else{
        				jedisCommands.lpush("cell:" + String.valueOf(this.imsimsg.getCell()), String.valueOf(this.imsimsg.getImsi()));
        			}
					*/
    			}
    		}
    		else{
    			Map <String,String> imsi_properties = new HashMap<String, String>();
    			imsi_properties.put("cell", String.valueOf(this.imsimsg.getCell()));
    			imsi_properties.put("lac", String.valueOf(this.imsimsg.getLac()));
    			imsi_properties.put("network_event_ts", this.imsimsg.getNetwork_event_ts());
				int imei = this.imsimsg.getImei();
				if(imei != 0){
					imsi_properties.put("imei", String.valueOf(imei));
				}    			
    			jedisCommands.hmset("imsi:" + imsi, imsi_properties);
   			
    			
    			jedisCommands.expire("imsi:" + imsi, this.expireInterval);
				jedisCommands.expire("imsitomsisdn:" + imsi, this.expireInterval);    			
    			
    			jedisCommands.lpush("cell:"+String.valueOf(this.imsimsg.getCell())+":"+String.valueOf(this.imsimsg.getLac()), imsi);    			
    			
    			
    			// check if the cell key exists, key will be now cell:<cellid>:<lac>
    			/*
    			Boolean cell_found=jedisCommands.exists("cell:"+String.valueOf(this.imsimsg.getCell())+":"+String.valueOf(this.imsimsg.getLac())); 
    			
    			
    			if (cell_found){
    				LOG.debug("Cell was found, adding the imsi to the cell");
    				//jedisCommands.hset("cell:"+this.imsimsg.getCell(), "imsi", this.imsimsg.getImsi());
    				jedisCommands.lpush("cell:"+String.valueOf(this.imsimsg.getCell())+":"+String.valueOf(this.imsimsg.getLac()), String.valueOf(this.imsimsg.getImsi()));
    			}
    			else{
    				//Map <String,String> cell_properties = new HashMap<String, String>();
    				//cell_properties.put("imsi", String.valueOf(this.imsimsg.getImsi()));
    				//jedisCommands.hmset("cell:" + this.imsimsg.getCell(), cell_properties);
    				jedisCommands.lpush("cell:"+String.valueOf(this.imsimsg.getCell())+":"+String.valueOf(this.imsimsg.getLac()), String.valueOf(this.imsimsg.getImsi()));
    			}
    			*/

    		}
    	}
    	catch(Exception e ){
    		//LOG.debug("Received error " + e.getMessage());
    		//e.printStackTrace();
    	}
        finally {
	        if (jedisCommands != null) {
	            returnInstance(jedisCommands);
	        }
	        this.collector.ack(input);
        }
    }

    @Override
    public void declareOutputFields(OutputFieldsDeclarer declarer) {
        // imsi, imsi values is a hashmap of multiple values
        declarer.declare(new Fields("imsi", "imsi_values"));
    }

}
