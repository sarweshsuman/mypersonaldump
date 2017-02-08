package com.proximus.rtls.main;


import com.proximus.rtls.redis.libs2.RedisConnectionManager;
import com.proximus.rtls.redis.libs2.Cell;
import com.proximus.rtls.redis.libs2.Imsi;
import com.proximus.rtls.redis.libs2.NCell;
import com.proximus.rtls.redis.libs2.RTLSObject;
import com.proximus.rtls.redis.libs2.ReadCellList;
import com.proximus.rtls.redis.libs2.StormThread;
import com.proximus.rtls.libs.RTLSServletContextListener;
import com.proximus.rtls.exception.RTLSException;

import java.io.IOException;
import java.text.ParseException;
import java.util.List;

import org.apache.log4j.Level;
import org.apache.log4j.Logger;

public class RealTimeLocationStoreSynchronous {
	ReadCellList readcellList;
	Logger logger = Logger.getLogger(RealTimeLocationStoreSynchronous.class);
	RTLSServletContextListener contextListener;

	public RealTimeLocationStoreSynchronous() throws IOException,RTLSException{
		this.readcellList = new ReadCellList(new RedisConnectionManager("localhost"),this.contextListener);
	}
	public RealTimeLocationStoreSynchronous(String redisserver,int redisport,int timeout,RTLSServletContextListener contextListener) throws IOException,RTLSException{
		this.contextListener=contextListener;
		this.readcellList = new ReadCellList(new RedisConnectionManager(redisserver,redisport,timeout),this.contextListener);
	}
	public void setRTLSServletContextListener(RTLSServletContextListener contextListener){
		this.contextListener=contextListener;
	}
	public Cell handleCellIdRequest_XML(String cellid) throws RTLSException{
		this.logger.trace("Recived request for cellid="+cellid);
		return this.readcellList.getAllIMSIInACell(cellid);
	}
	public List<NCell> returnCellList_XML() throws RTLSException{
		this.logger.trace("Recevied request to send list of Cell");
		return this.readcellList.getCellList();
	}
	public List<StormThread> returnThreadInfo_XML() throws RTLSException{
		this.logger.trace("Recevied request to send Latest Records processed in Redis ");
		return this.readcellList.getStormThreadDetails();
	}
	public void exit(){
		try{
			this.readcellList.pipe.close();
			this.readcellList.connection.close();
		}
		catch(IOException e){

		}
		this.readcellList=null;
	}
}
