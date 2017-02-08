package com.proximus.rtls.redis.libs2;

import java.util.Map;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

@XmlRootElement(name="Thread")
public class StormThread {
	String threadid;
	
	String recordsProcessed;
	String millionRecordsProcessed;
	String lastImsiCommited;
	
	String lastRecordEventTime;
	
	public StormThread(){
		
	}
	public StormThread(String thread,Map<String,String> props){
		String[] arr = thread.split(":");
		this.threadid = arr[1];
		this.lastRecordEventTime=props.get("latestEventTimeProcessed");
		this.recordsProcessed=props.get("recordsProcessed");
		this.millionRecordsProcessed=props.get("millionRecordsProcessed");
		this.lastImsiCommited=props.get("lastimsi");
	}
	
	@XmlElement
	public void setThreadid(String id){
		this.threadid=id;
	}
	@XmlElement
	public void setLastRecordEventTime(String eventTime){
		this.lastRecordEventTime=eventTime;
	}	
	@XmlElement
	public void setRecordsProcessed(String recordsProcessed){
		this.recordsProcessed=recordsProcessed;
	}	
	@XmlElement
	public void setMillionRecordsProcessed(String millionRecordsProcessed){
		this.millionRecordsProcessed=millionRecordsProcessed;
	}	
	@XmlElement
	public void setLastImsiCommited(String lastImsiCommited){
		this.lastImsiCommited=lastImsiCommited;
	}	
	
	public String getThreadid(){
		return this.threadid;
	}
	public String getRecordsProcessed(){
		return this.recordsProcessed;
	}
	public String getMillionRecordsProcessed(){
		return this.millionRecordsProcessed;
	}		
	public String getLastImsiCommited(){
		return this.lastImsiCommited;
	}		
	public String getLastRecordEventTime(){
		return this.lastRecordEventTime;
	}
	
}
