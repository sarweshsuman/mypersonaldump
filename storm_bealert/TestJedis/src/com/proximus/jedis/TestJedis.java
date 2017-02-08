package com.proximus.jedis;

import redis.clients.jedis.*;

public class TestJedis {
	public static void main(String args[]){
		Jedis jedis = new Jedis("redis-10733.redislabscluster.bc",10733);
		System.out.println(jedis.ping());
		jedis.set("sarwesh", "suman");
		jedis.close();
	}
}
