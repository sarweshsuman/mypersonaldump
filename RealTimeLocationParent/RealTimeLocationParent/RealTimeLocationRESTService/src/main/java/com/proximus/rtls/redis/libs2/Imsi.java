package com.proximus.rtls.redis.libs2;

import java.util.Map;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

@XmlRootElement(name="Imsi")
public class Imsi implements RTLSObject{
	String cell;
	String lac;
	String networkeventts;
	String imei;
	
	public Imsi(){
		
	}
	
	public Imsi(Map<String,String> imsi_props){
		
		this.cell=imsi_props.get("cell");
		this.lac=imsi_props.get("lac");
		this.networkeventts=imsi_props.get("network_event_ts");
		this.imei=imsi_props.get("imei");
		
		if(this.cell == null ){
			this.cell="unknown";
		}
		if(this.lac == null ){
			this.lac="unknown";
		}
		if(this.networkeventts == null ){
			this.networkeventts="unknown";
		}
		if(this.imei == null ){
			this.imei="unknown";
		}
	}
	
	@XmlElement
	public void setCell(String cell){
		this.cell=cell;
	}
	@XmlElement
	public void setLac(String lac){
		this.lac=lac;
	}
	@XmlElement
	public void setNetworkeventts(String networkeventts){
		this.networkeventts=networkeventts;
	}
	@XmlElement
	public void setImei(String imei){
		this.imei=imei;
	}
	public String getCell(){
		return this.cell;
	}	
	public String getLac(){
		return this.lac;
	}
	public String getNetworkeventts(){
		return this.networkeventts;
	}
	public String getImei(){
		return this.imei;
	}	
}