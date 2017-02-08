package com.proximus.rtls.libs;

import java.util.List;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

import com.proximus.rtls.redis.libs2.*;
import com.proximus.rtls.redis.libs2.Cell;
import com.proximus.rtls.redis.libs2.RTLSObject;

@XmlRootElement(name="request")
public class RTLSResponse implements RTLSObject{

	Long requestId;
	String OFileName;
	int errorcode=0;
	String errorDescription="OK";
	List<Cell> celldetails;

	public RTLSResponse(){
	}

	public RTLSResponse(Long reqId,String OFileName){
		this.requestId=reqId;
		this.OFileName=OFileName;
	}

	@XmlElement
	public void setRequestId(Long reqId){
		this.requestId=reqId;
	}
	@XmlElement
	public void setOFileName(String OFileName){
		this.OFileName=OFileName;
	}
	@XmlElement
	public void setErrorcode(int errorcode){
		this.errorcode=errorcode;
	}
	@XmlElement
	public void setErrorDescription(String errorDescription){
		this.errorDescription=errorDescription;
	}
	@XmlElement
	public void setCelldetails(List<Cell> cell){
		this.celldetails=cell;
	}
	public List<Cell> getCelldetails(){
		return this.celldetails;
	}

	public Long getRequestId(){
		return this.requestId;
	}
	public String getOFileName(){
		return this.OFileName;
	}
	public int getErrorcode(){
		return this.errorcode;
	}
	public String getErrorDescription(){
		return this.errorDescription;
	}
}
