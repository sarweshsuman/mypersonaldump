package com.proximus.rtls.redis.libs2;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

@XmlRootElement(name="Cells")
public class NCell implements RTLSObject{
	String cell;
	long countOfImsis;

	public NCell(){

	}
	@XmlElement
	public void setCell(String cell){
		this.cell=cell;
	}
	@XmlElement
	public void setCountOfImsis(long count){
		this.countOfImsis=count;
	}
	public String getCell(){
		return this.cell;
	}
	public long getCountOfImsis(){
		return this.countOfImsis;
	}
}
