package com.proximus.rtls.redis.libs2;

import redis.clients.jedis.Jedis;

public class RedisConnectionManager extends Jedis {
	//Jedis connection;
	String server;
	Integer port;
	int timeout;
	public RedisConnectionManager(String server){
		super(server);
		this.server=server;		
	}	
	public RedisConnectionManager(String server , Integer port,int timeout){
		super(server,port,timeout);
		this.server=server;
		this.port=port;
		this.timeout=timeout;
	}
}
