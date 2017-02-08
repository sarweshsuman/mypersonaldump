package com.proximus.rtls.exception;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

@XmlRootElement(name="exception")
public class RTLSException extends Exception {
	private static final long serialVersionUID = 1L;
	
	private String message;
	
	public RTLSException(String message){
		super(message);
		this.message=message;
	}
	public String getMessage(){
		return this.message;
	}
	@XmlElement
	public void setMessage(String message){
		this.message=message;
	}
}
