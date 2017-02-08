package com.proximus.rtls.redis.libs2;

import java.io.Serializable;
import java.util.ArrayList;
//import java.util.HashMap;
import java.util.List;
//import java.util.Map;
//import java.util.Map.Entry;

//import javax.xml.bind.annotation.XmlAttribute;
import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;
//import javax.xml.bind.annotation.adapters.XmlJavaTypeAdapter;

//import com.proximus.rtls.marshalling.MsisdnAdapter;

@XmlRootElement(name="cell")
public class Cell implements RTLSObject{
	
	//@XmlJavaTypeAdapter(MsisdnAdapter.class)
	private List<String> msisdn;
	private String cellid;
	private String lac;
	
	public Cell(){}
	public Cell(String cellid,List<String> msisdns){
		String args[] = cellid.split(":");
		this.cellid = args[0];
		this.lac = args[1];		
		this.msisdn=msisdns;
	}
	public String getCellid(){
		return this.cellid;
	}
	@XmlElement
	public void setCellid(String cellid){
		this.cellid=cellid;
	}
	@XmlElement
	public void setMsisdn(List<String> msisdns){
		this.msisdn=msisdns;
	}
	@XmlElement
	public void setLac(String lac){
		this.lac=lac;
	}
	public String getLac(){
		return this.lac;
	}
	public List<String> getMsisdn(){
		return this.msisdn;
	}
	public String toString(){
		return this.cellid+"-"+this.lac+","+this.msisdn.toString();
	}
	public List<String> toListOfStrings(){
		List<String> return_value = new ArrayList<String>();
		for(String msisdn : this.msisdn){
			return_value.add(this.cellid+"-"+this.lac+","+msisdn);
		}
		return return_value;
	}
}
