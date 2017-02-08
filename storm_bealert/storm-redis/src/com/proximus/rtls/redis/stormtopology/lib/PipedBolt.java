package com.proximus.rtls.redis.stormtopology.lib;

import java.io.Serializable;
import java.io.UnsupportedEncodingException;
import java.util.HashMap;
import java.util.Map;

import java.io.IOException ;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import backtype.storm.topology.IRichBolt;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.Pipeline;
import redis.clients.jedis.Response;
import backtype.storm.topology.OutputFieldsDeclarer;
import backtype.storm.task.OutputCollector;
import backtype.storm.task.TopologyContext;
import backtype.storm.tuple.Fields;
import backtype.storm.tuple.Tuple;

public class PipedBolt implements IRichBolt{
	private static final Logger LOG = LoggerFactory.getLogger(PipedBolt.class);
	private ImsiMessage imsimsg;
	int expireInterval;
	Jedis jedis;
	Pipeline pipe;
    OutputCollector _collector;

    String server;
    int port;
    int database;
    
    public PipedBolt(String server, int port,int database,int expire){
    	this.server=server;
    	this.port=port;
    	this.database=database;
    	this.expireInterval=expire;
    }
    
    @Override
    public void prepare(Map conf, TopologyContext context, OutputCollector collector) {
        _collector = collector;
    	this.jedis=new Jedis(this.server,this.port);
    	this.jedis.connect();
    	this.jedis.select(this.database);  
    	this.pipe=this.jedis.pipelined();    	
    }

    @Override
    public void execute(Tuple input) {
    	byte[] bytes = input.getBinary(input.fieldIndex("bytes"));
    	try {
			String osixrec= new String (bytes,"UTF-8");
			this.imsimsg=new ImsiMessage(osixrec);
			if ( this.imsimsg.getInterfacetype().equalsIgnoreCase("GB_V7") && this.imsimsg.getTransactiontype().equalsIgnoreCase("RAU") && this.imsimsg.getTransactionsubtype().equalsIgnoreCase("RAU")){			
				this._collector.ack(input);
				return;				
			}
		} catch (UnsupportedEncodingException e) {
			this._collector.ack(input);
			return;
		}
    	try{
    		String imsi = this.imsimsg.getImsi();
    		HashMap<String,Response<String>> piped = new HashMap<String,Response<String>>();
    		this.pipe.clear();
    		piped.put("cell",this.pipe.hget("imsi:"+imsi, "cell"));
    		piped.put("lac",this.pipe.hget("imsi:"+imsi, "lac"));
    		this.pipe.sync();
    		String cell=piped.get("cell").get();
    		String lac=piped.get("lac").get();
    		this.pipe.clear();
    		piped.clear();
    		
    		if (cell!=null){
    			Map<String, String> properties = this.jedis.hgetAll("imsi:" + imsi);
    			ImsiMessage storedimsi= new ImsiMessage(imsi,properties);
    			if (storedimsi.getNetworkEventDate().isBefore(this.imsimsg.getNetworkEventDate())){
    				
    				this.pipe.hset("imsi:" + imsi, "cell", String.valueOf(this.imsimsg.getCell()));
    				this.pipe.hset("imsi:" + imsi, "lac", String.valueOf(this.imsimsg.getLac()));
    				this.pipe.hset("imsi:" + imsi, "network_event_ts", String.valueOf(this.imsimsg.getNetwork_event_ts()));
    				
    				int imei = this.imsimsg.getImei();
    				if(imei != 0){
    					this.pipe.hset("imsi:" + imsi, "imei", String.valueOf(imei));
    				}
    				
    				this.pipe.expire("imsi:" + imsi, this.expireInterval);
    				this.pipe.expire("imsitomsisdn:" + imsi, this.expireInterval);
    				
    				Boolean cell_found=this.jedis.exists("cell:"+cell+":"+lac);

    				if (cell_found){
    					this.pipe.lrem("cell:"+cell+":"+lac, 0, imsi);
    				}
    				this.pipe.lpush("cell:" + String.valueOf(this.imsimsg.getCell()) + ":"+ String.valueOf(this.imsimsg.getLac()), imsi);
    				
    				this.pipe.sync();
    				this.pipe.clear();    				
    			}
    		}
    		else{
    			//Map <String,String> imsi_properties = new HashMap<String, String>();
    			this.pipe.hset("imsi:" + imsi,"cell", String.valueOf(this.imsimsg.getCell()));
    			this.pipe.hset("imsi:" + imsi,"lac", String.valueOf(this.imsimsg.getLac()));
    			this.pipe.hset("imsi:" + imsi,"network_event_ts", this.imsimsg.getNetwork_event_ts());
				int imei = this.imsimsg.getImei();
				if(imei != 0){
					this.pipe.hset("imsi:" + imsi,"imei", String.valueOf(imei));
				}    			
    			this.pipe.expire("imsi:" + imsi, this.expireInterval);
				this.pipe.expire("imsitomsisdn:" + imsi, this.expireInterval);    			
    			this.pipe.lpush("cell:"+String.valueOf(this.imsimsg.getCell())+":"+String.valueOf(this.imsimsg.getLac()), imsi);    			
    			this.pipe.sync();
    		}
    	}
    	catch(Exception e ){
    		System.out.println("Excception " + e.getMessage());
    	}
        finally {
	        this._collector.ack(input);
        }
    }

    @Override
    public void cleanup() {
    	try{
    		this.pipe.close();
    		this.jedis.close();
    	}
    	catch(IOException e){
    		System.out.println("IOExcception in cleanup " + e.getMessage());    		
    	}
    }

    @Override
    public void declareOutputFields(OutputFieldsDeclarer declarer) {
        declarer.declare(new Fields("imsi", "imsi_values"));
    }

    @Override
    public Map<String, Object> getComponentConfiguration() {
        return null;
    }	
}