package com.proximus.rtls.redis.libs2;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Set;

import redis.clients.jedis.Pipeline;
import redis.clients.jedis.Response;

import org.apache.log4j.Logger;
import org.joda.time.DateTime;
import org.joda.time.format.DateTimeFormat;


public class LoadImsiMsisdnMapping {
	RedisConnectionManager connection;
	Pipeline pipe;
	Logger logger = Logger.getLogger(LoadImsiMsisdnMapping.class);
	int batchedRequest=10000;
	DateTime last_refreshed_at;

	//public HashMap<String,String> imsitomsisdn = new HashMap<String,String>();
	//public Properties imsitomsisdn = new Properties();
	public HashMap<String,String> imsitomsisdn = new HashMap<String,String>();

	public LoadImsiMsisdnMapping(){
		this.connection = new RedisConnectionManager("localhost",6379,50000);
		this.pipe = this.connection.pipelined();
	}

	public LoadImsiMsisdnMapping(String hostname,int port,int timeout){
		this.connection = new RedisConnectionManager(hostname,port,timeout);
		this.pipe = this.connection.pipelined();
	}

	public void load(){

		this.pipe.clear();
		Response<String> lock_res = this.pipe.getSet("lock_imsitomsisdn_mapping", "2");
		this.pipe.sync();
		String lock = lock_res.get();
		this.pipe.clear();

		if(lock !=null && lock.equalsIgnoreCase("0") == false ){
			this.logger.debug("Operation in progress by LoadPNIFile, will exit now");
			return;
		}

		DateTime dt_from_redis;
		Response<String> res = this.pipe.get("reset_imsitomsisdn_mapping");
		this.pipe.sync();
		String reset = res.get();
		this.pipe.clear();

		if((reset == null || (reset !=null && reset.equalsIgnoreCase("false"))) && this.last_refreshed_at != null){

			this.logger.trace("Checking the last refreshed date");

			Response<String> dt_response = this.pipe.get("imsitomsisdn_mapping_refreshed_at");

			this.pipe.sync();

			dt_from_redis = DateTime.parse(dt_response.get(),DateTimeFormat.forPattern("yyyy-MM-dd HH:mm:ss.SSS"));

			this.pipe.clear();

			if(this.last_refreshed_at.isBefore(dt_from_redis) == false ){
				this.logger.trace("No New Data Found");

				this.pipe.set("lock_imsitomsisdn_mapping", "0");
				this.pipe.sync();
				this.pipe.clear();

				return;
			}

			long starttime = System.currentTimeMillis();

			this.logger.trace("New Data Found");

			this.pipe.clear();

			// Check ADD UPDATE DELETE lists

			Response<List<String>> array_add_res = this.pipe.lrange("add",0,-1);
			Response<List<String>> array_delete_res = this.pipe.lrange("delete",0,-1);
			Response<List<String>> array_update_res = this.pipe.lrange("update",0,-1);

			this.pipe.sync();

			List<String> array_add=array_add_res.get();
			List<String> array_delete=array_delete_res.get();
			List<String> array_update=array_update_res.get();

			this.pipe.clear();

			HashMap<String,Response<String>> response = new HashMap<String,Response<String>>();

			for(String add : array_add ){
				response.put(add, this.pipe.get("imsitomsisdn:"+add));
				if(response.size() == this.batchedRequest){
					this.pipe.sync();
					for(String imsi : response.keySet()){
						String msisdn = response.get(imsi).get();
						if(msisdn == null ){
							continue;
						}
						this.imsitomsisdn.put(imsi, msisdn);
					}
					response.clear();
					this.pipe.clear();
				}
			}

			this.pipe.sync();

			for(String imsi : response.keySet()){
				String msisdn = response.get(imsi).get();
				if(msisdn == null ){
					continue;
				}
				this.imsitomsisdn.put(imsi, msisdn);
			}

			response.clear();
			this.pipe.clear();

			for(String del : array_delete){
				this.imsitomsisdn.remove(del);
			}

			for(String up : array_update){
				response.put(up, this.pipe.get("imsitomsisdn:"+up));
				if(response.size() == this.batchedRequest){
					this.pipe.sync();
					for(String imsi : response.keySet()){
						String msisdn = response.get(imsi).get();
						if(msisdn == null ){
							this.imsitomsisdn.remove(imsi);
							continue;
						}
						this.imsitomsisdn.put(imsi, msisdn);
					}
					response.clear();
					this.pipe.clear();
				}
			}

			this.pipe.sync();

			for(String imsi : response.keySet()){
				String msisdn = response.get(imsi).get();
				if(msisdn == null ){
					this.imsitomsisdn.remove(imsi);
					continue;
				}
				this.imsitomsisdn.put(imsi, msisdn);
			}

			response.clear();

			this.pipe.clear();

			// sending delete command for all the elements in add , update, delete

			/*
			for(String item : array_add){
				this.pipe.lrem("add", 0, item);
			}

			this.pipe.sync();
			this.pipe.clear();

			for(String item : array_update){
				this.pipe.lrem("update", 0, item);
			}

			this.pipe.sync();
			this.pipe.clear();

			for(String item : array_delete){
				this.pipe.lrem("delete", 0, item);
			}
			 */
			// Now that LoadFile and This process are serialized so i will straight away delete the keys
			this.pipe.del("add");
			this.pipe.del("delete");
			this.pipe.del("update");
			this.pipe.sync();
			this.pipe.clear();

			long endtime = System.currentTimeMillis();

			this.logger.info("Refresh Completed in "+(endtime-starttime)+"ms , added "+array_add.size() + " records , deleted "+array_delete.size()+" records, updated "+array_update.size()+" records");

			this.last_refreshed_at=DateTime.now();

		}
		else {

				long starttime = System.currentTimeMillis();
				this.logger.trace( starttime + " Refreshing complete cache for imsi to msisdn mapping ");

				try{
					this.pipe.clear();

					this.pipe.set("reset_imsitomsisdn_mapping", "false");

					/*

					Response<Set<String>> imsis_response = this.pipe.keys("imsitomsisdn:*");

					this.pipe.sync();

					Set<String> imsis = imsis_response.get();

					this.logger.trace(System.currentTimeMillis() + " Recevied the response from redis server ");

					FileWriter fw = new FileWriter("/tmp/loadimsimsisdn.keys.txt");
					BufferedWriter bw = new BufferedWriter(fw,1048576*10);

					for(String imsi : imsis){
						bw.write(imsi+"\n");
					}
					bw.close();
					imsis=null;

					this.pipe.clear();

					Map<String,Response<String>> imsi_msisdn_response = new HashMap<String,Response<String>>();
					FileReader fr = new FileReader("/tmp/loadimsimsisdn.keys.txt");
					BufferedReader br = new BufferedReader(fr,1048576*10);

					fw = new FileWriter("/tmp/loadimsimsisdn.mapping.txt");
					bw = new BufferedWriter(fw,1048576*10);
					String imsi;
					while((imsi = br.readLine()) != null ){
						imsi_msisdn_response.put(imsi, this.pipe.get(imsi));
						if(imsi_msisdn_response.size() == this.batchedRequest){
							this.pipe.sync();
							for(String ims : imsi_msisdn_response.keySet()){
								String msisdn = imsi_msisdn_response.get(ims).get();
								if(msisdn == null)
									continue;
								bw.write(ims.split(":")[1]+"="+msisdn+"\n");
							}
							imsi_msisdn_response.clear();
							this.pipe.clear();
						}
					}
					this.pipe.sync();

					for(String ims : imsi_msisdn_response.keySet()){
						String msisdn = imsi_msisdn_response.get(ims).get();
						if(msisdn == null)
							continue;
						bw.write(ims.split(":")[1]+"="+msisdn+"\n");
					}
					this.pipe.clear();
					imsi_msisdn_response=null;
					br.close();
					bw.close();

					this.imsitomsisdn.clear();

					this.imsitomsisdn.load(new FileReader("/tmp/loadimsimsisdn.mapping.txt"));

					*/

					// No files
					this.imsitomsisdn.clear();

					Response<Set<String>> imsis_response = this.pipe.keys("imsitomsisdn:*");

					this.pipe.sync();

					Set<String> imsis = imsis_response.get();

					this.logger.trace(System.currentTimeMillis() + " Recevied the response from redis server ");

					this.pipe.clear();

					Map<String,Response<String>> imsi_msisdn_response = new HashMap<String,Response<String>>();

					for(String imsi : imsis ){
						imsi_msisdn_response.put(imsi,this.pipe.get(imsi));
						if(imsi_msisdn_response.size() == this.batchedRequest ){
							this.pipe.sync();
							for(String ims : imsi_msisdn_response.keySet()){
								String msisdn = imsi_msisdn_response.get(ims).get();
								if(msisdn == null)
									continue;
								this.imsitomsisdn.put(ims.split(":")[1],msisdn);
							}
							imsi_msisdn_response.clear();
							this.pipe.clear();
						}
					}

					this.pipe.sync();
					for(String ims : imsi_msisdn_response.keySet()){
						String msisdn = imsi_msisdn_response.get(ims).get();
						if(msisdn == null)
							continue;
						this.imsitomsisdn.put(ims.split(":")[1],msisdn);
					}
					imsi_msisdn_response.clear();
					this.pipe.clear();

					long endtime = System.currentTimeMillis();

					this.logger.info("Refresh Completed in "+(endtime-starttime)+"ms , loaded "+this.imsitomsisdn.size() + " records");

					this.pipe.clear();

					if(this.imsitomsisdn.size() != 0)
						this.last_refreshed_at=DateTime.now();

			}catch(Exception e){
				System.out.println("Exception in load "+e.getMessage());
				this.logger.debug("Exception in load "+e.getMessage());
			}
		} // end of else
		this.pipe.set("lock_imsitomsisdn_mapping", "0");
		this.pipe.sync();
		this.pipe.clear();
	}
}
