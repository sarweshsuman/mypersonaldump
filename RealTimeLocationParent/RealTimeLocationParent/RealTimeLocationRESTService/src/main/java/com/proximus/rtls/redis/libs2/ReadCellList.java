package com.proximus.rtls.redis.libs2;

import com.proximus.rtls.libs.RTLSServletContextListener;
import com.proximus.rtls.redis.libs2.RedisConnectionManager;
import com.proximus.rtls.exception.RTLSException;

import java.io.BufferedWriter;
import java.io.IOException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Stack;

import redis.clients.jedis.Pipeline;
import redis.clients.jedis.Response;

import java.util.Timer;
import java.util.TimerTask;

import org.apache.log4j.Logger;

public class ReadCellList implements Runnable{

	public RedisConnectionManager connection;
	public Pipeline pipe;
	String prefix="cell";
	String imsimsisdnlookupPrefix="imsitomsisdn";
	Cell cell;
	Logger logger = Logger.getLogger(ReadCellList.class);

	RTLSServletContextListener contextListener;
	ArrayList<String> logging_buffer;

	// For threads only,

	String threadid="unthreaded";
	BufferedWriter bw;
	String[] cellids_for_thread_to_process;

	public ReadCellList(RedisConnectionManager connection,RTLSServletContextListener contextListener){
		this.connection=connection;
		this.pipe=this.connection.pipelined();
		this.contextListener=contextListener;
		this.logging_buffer=this.contextListener.logger_buffer;
	}
	public ReadCellList(RedisConnectionManager connection,String prefix,String imsimsisdnlookupPrefix,RTLSServletContextListener contextListener){
		this.connection=connection;
		this.pipe=this.connection.pipelined();
		this.prefix=prefix;
		this.imsimsisdnlookupPrefix=imsimsisdnlookupPrefix;
		this.contextListener=contextListener;
		this.logging_buffer=this.contextListener.logger_buffer;
	}
	public Cell getAllIMSIInACell(String cellid) throws RTLSException
	{

		this.logger.trace("Recevied request");

		if(this.connection.ping().equalsIgnoreCase("PONG")){
			this.logger.trace("Connection exists to redis server");
		}
		else {
			this.logger.error("Connection does not exists to redis server");
			throw new RTLSException("Connecion problem");
		}

		Set<String> listIMSI = this.connection.hkeys(this.prefix+":"+cellid);

		if(listIMSI.isEmpty()){
			this.logger.debug("No IMSI found for given cellid:lac "+cellid.toString());
			throw new RTLSException("No IMSI found for given cellid:lac");
		}

		ArrayList<String> msisdns = new ArrayList<String>();

		for(String imsi : listIMSI ){
			String msisdn=this.contextListener.mapping.imsitomsisdn.get(imsi);
			if(msisdn != null){
				msisdns.add(msisdn);
			}
		}

		if(msisdns.isEmpty() == true ){
			this.logger.debug("MSISDN List is empty for cellid "+cellid);
			throw new RTLSException("No MSISDN found for cellid "+cellid.toString()+" or cellid does not exists in the database");
		}
		else {
			this.logger.trace("Number of msisdn recevied "+msisdns.size());
		}
		cell = new Cell(cellid,msisdns);
		this.logger.trace("Returning cell as "+cell.toString());
		return cell;

	}

	public String[] getAllCellName() throws RTLSException {

		this.pipe.clear();

		Response<Set<String>> celllist_response = this.pipe.keys("cell:*");

		this.pipe.sync();

		Set<String> celllist = celllist_response.get();

		this.pipe.clear();

		HashMap<String,Response<Long>> cell_length_res = new HashMap<String,Response<Long>>();

		for(String cell : celllist ){
			cell_length_res.put(cell,this.pipe.hlen(cell));
		}

		this.pipe.sync();

		ArrayList<String> tiny_cell = new ArrayList<String>();
		ArrayList<String> small_cell = new ArrayList<String>();
		ArrayList<String> big_cell = new ArrayList<String>();
		ArrayList<String> huge_cell = new ArrayList<String>();


		for(String cell: celllist){
			long count = cell_length_res.get(cell).get();
			if(count < 100 ){
				tiny_cell.add(cell);
			}
			else if ( count < 1000 ){
				small_cell.add(cell);
			}
			else if ( count < 50000 ){
				big_cell.add(cell);
			}
			else{
				huge_cell.add(cell);
			}
		}

		this.pipe.clear();

		ArrayList<String> cell_to_process = new ArrayList<String>();

		cell_to_process.addAll(huge_cell.subList(0, huge_cell.size()/2));
		cell_to_process.addAll(small_cell);
		cell_to_process.addAll(big_cell.subList(0, big_cell.size()/2));
		cell_to_process.addAll(tiny_cell.subList(0, tiny_cell.size()/2));
		cell_to_process.addAll(big_cell.subList(big_cell.size()/2, big_cell.size()));
		cell_to_process.addAll(tiny_cell.subList( tiny_cell.size()/2,tiny_cell.size()));
		cell_to_process.addAll(huge_cell.subList(huge_cell.size()/2,huge_cell.size()));

		String[] totalCell = cell_to_process.toArray(new String[cell_to_process.size()]);

		return totalCell;
	}

	public List<String> getNCellInfo(String[] celllist) throws RTLSException{

		HashMap<String,String> mapping = this.contextListener.mapping.imsitomsisdn;

		ArrayList<String> totalCell = new ArrayList<String>();
		ArrayList<Response<Set<String>>> response = new ArrayList<Response<Set<String>>>();

		this.pipe.clear();

		long starttime = System.currentTimeMillis();

		for(String cell : celllist){
			response.add(this.pipe.hkeys(this.prefix+":"+cell));
		}

		long starttime2 = System.currentTimeMillis();

		this.logging_buffer.add("Thread "+this.threadid +" prepared in "+(starttime2-starttime) +"ms");

		this.pipe.sync();

		long starttime3 = System.currentTimeMillis();

		this.logging_buffer.add("Thread "+this.threadid +" Sync completed in "+(starttime3-starttime2) +"ms");

		this.pipe.clear();

		int sum=0;
		int count_imsis=0;
		int count_msisdn_miss=0;
		for(int i=0;i<celllist.length;i++){
			long st = System.currentTimeMillis();
			Set<String> imsis = response.get(i).get();
			long endt = System.currentTimeMillis();
			sum += (endt-st);
			//List<String> msisdns = new ArrayList<String>();
			if(imsis.isEmpty()){
				count_msisdn_miss++;
				continue;
			}
			long starttime5 = System.currentTimeMillis();
			for(String imsi:imsis){
				String msisdn = mapping.get(imsi);//this.contextListener.mapping.imsitomsisdn.get(imsi);
				if(msisdn == null){
					continue;
				}
				totalCell.add(celllist[i]+","+msisdn);
				//msisdns.add(msisdn);
			}
			count_imsis += imsis.size();
			imsis=null;
			long starttime6 = System.currentTimeMillis();
			//this.logging_buffer.add("Thread "+this.threadid +" fetched imsi completed in "+(starttime6-starttime5) +"ms "+imsis.size() );
			/*
			if(msisdns.isEmpty() == false){
				totalCell.add(new Cell(celllist[i]+","msisdns));
			}
			*/
		}
		long starttime4 = System.currentTimeMillis();

		this.logging_buffer.add("Thread "+this.threadid +" fetched msisdns completed in "+(starttime4-starttime3) +"ms and to save data from response it took total "+sum + "ms count="+count_imsis +" msisdn miss="+count_msisdn_miss );
		return totalCell;
	}


	/*
	public List<Cell> getNCellInfo(String[] celllist) throws RTLSException{

		ArrayList<Cell> totalCell = new ArrayList<Cell>();
		ArrayList<Response<List<String>>> response = new ArrayList<Response<List<String>>>();

		//this.logger.trace(this.threadid + " number of cell:lac to process "+celllist.length);

		this.pipe.clear();
		for(String cell : celllist){
			response.add(this.pipe.lrange(this.prefix+":"+cell, 0, -1));
		}

		//this.logger.trace(this.threadid + " Starting sync for all imsi with all celllist ");
		this.pipe.sync();
		//this.logger.trace(this.threadid + " Sync complete ");

		this.pipe.clear();

		//this.logger.trace(this.threadid + " Trying for list of msisdns ");

		for(int i=0;i<celllist.length;i++){
			List<String> imsis = response.get(i).get();
			List<String> msisdns = new ArrayList<String>();
			if(imsis.isEmpty()){
				continue;
			}
			for(String imsi:imsis){
				String msisdn = this.contextListener.mapping.imsitomsisdn.getProperty(imsi);
				if(msisdn == null){
					continue;
				}
				msisdns.add(msisdn);
			}
			if(msisdns.isEmpty() == false){
				totalCell.add(new Cell(celllist[i],msisdns));
			}
		}
		//this.logger.trace(this.threadid + " List of cell returning "+totalCell.size());
		return totalCell;
	}
	*/
	public List<NCell> getCellList() throws RTLSException{

		if(this.connection.ping().equalsIgnoreCase("PONG")){
			this.logger.trace("Connection exists to redis server");
		}
		else {
			this.logger.error("Connection does not exists to redis server");
			throw new RTLSException("Connecion problem");
		}

		List<String> result = new ArrayList<String>();
		HashMap<String,Response<Long>> response = new HashMap<String,Response<Long>>();

		Set<String> celllist = this.connection.keys("cell:*");
		this.pipe.clear();

		for(String cell : celllist){
			response.put(cell,this.pipe.hlen(cell));
		}
		this.pipe.sync();

		List<NCell> list = new ArrayList<NCell>();
		for(String cell : response.keySet()){
			NCell ncell = new NCell();
			Long count = response.get(cell).get();
			ncell.setCell(cell);
			ncell.setCountOfImsis(count);
			list.add(ncell);
		}
		this.pipe.clear();

		this.logger.trace("Returing list of cell "+result.size());
		return list;
	}
	public List<StormThread> getStormThreadDetails() throws RTLSException{

		if(this.connection.ping().equalsIgnoreCase("PONG")){
			this.logger.trace("Connection exists to redis server");
		}
		else {
			this.logger.error("Connection does not exists to redis server");
			throw new RTLSException("Connecion problem");
		}

		Set<String> threads = this.connection.keys("Thread:*");
		HashMap<String,Response<Map<String,String>>> response = new HashMap<String,Response<Map<String,String>>>();
		List<StormThread> list = new ArrayList<StormThread>();

		this.pipe.clear();

		for(String thd : threads){
			response.put(thd,this.pipe.hgetAll(thd));
		}
		this.pipe.sync();

		for(String thd : response.keySet()){
			Map<String,String> thd_detail = response.get(thd).get();
			StormThread st = new StormThread(thd,thd_detail);
			list.add(st);
		}
		this.pipe.clear();
		this.logger.trace("Returning list of storm thread "+list.size());
		return list;
	}


	//Threading implementation

	public void start(String name, String[] cellids,BufferedWriter bw){
		this.threadid=name;
		this.cellids_for_thread_to_process=cellids;
		this.bw=bw;

	}

	public void run(){
		if (this.cellids_for_thread_to_process == null)
			return;
		if (this.bw == null)
			return;
		try{
			long starttime=System.currentTimeMillis();
			/*
			List<Cell> celllist_objs  = this.getNCellInfo(this.cellids_for_thread_to_process);
			for (Cell cell_super : celllist_objs){
				Cell cell = (Cell)cell_super;
				List<String> result = cell.toListOfStrings();
				for(String item : result){
					synchronized(this)
					{
						this.bw.write(item+"\n");
					}
				}
			}
			*/

			List<String> celllist_objs  = this.getNCellInfo(this.cellids_for_thread_to_process);
			for (String record : celllist_objs){
					//String record1 = record.replace(":", "-");
					synchronized(this)
					{
						this.bw.write(record+"\n");
					}
			}
			long endtime=System.currentTimeMillis();
			this.cellids_for_thread_to_process=null;
			this.pipe.close();
			this.connection.close();
			this.connection=null;
			celllist_objs=null;
			this.logging_buffer.add("Thread "+this.threadid + " completed in "+(endtime-starttime) + "ms");
		}
		catch(Exception e){
			this.logging_buffer.add("Exception seen "+e.getMessage());
			try{
				this.pipe.close();
				this.connection.close();
			}
			catch(IOException e2){
				this.logging_buffer.add("Exception seen "+e2.getMessage());
			}
			this.connection=null;
			return;
		}
	}

}
