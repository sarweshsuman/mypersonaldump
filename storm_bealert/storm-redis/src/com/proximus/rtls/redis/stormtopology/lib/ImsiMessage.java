package com.proximus.rtls.redis.stormtopology.lib;

import java.util.HashMap;
import java.io.UnsupportedEncodingException;
import java.util.Map;

import org.joda.time.DateTime;
import org.joda.time.format.DateTimeFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.esotericsoftware.minlog.Log;

public class ImsiMessage {
	private static final Logger LOG = LoggerFactory.getLogger(ImsiMessage.class);
	//IUPS_V12|72108182760662744|2015-08-14 13:47:10.941|206012222176697||9113|||44818|RAU|RAU|X|X|X|X|0|2015-08-14 13:47:13.808|10.42.94.81

	private String interfacetype;
	private String process_number;
	private String network_event_ts;
	private String imsi;
	private int imei;
	private int lac;
	private int rac;
	private int tac;
	private int cell;
	private String transactiontype;
	private String transactionsubtype;
	private String error_code1;
	private String error_code2;
	private String error_code3;
	private String error_code4;
	private String error_code5;
	private String event_date;
	private String ipadress;

    /**
     * Constructor for an imsi message when read from redis store
     *
     * @param  imsi  the imsi key value in string format
     * @param  imsiproperties  The values from redis stored in a Map
     */
	public ImsiMessage(String imsi,  Map<String, String> imsiproperties){
		this.imsi=imsi;
		this.cell=Integer.parseInt(imsiproperties.get("cell"));
		this.network_event_ts=imsiproperties.get("network_event_ts");
		this.lac=Integer.parseInt(imsiproperties.get("lac"));
	}

    /**
     * Constructor for an imsi message when a tuple is read from kafka
     *
     * @param  OsixRec	The record decoded in string format coming from kafka
     */
	public ImsiMessage(String OsixRec) throws UnsupportedEncodingException{
		//Split up the record by using the pipe sign as delimiter
		try{
			String[] value_split = OsixRec.split("\\|");
			if (value_split.length == 0 ){
				throw new UnsupportedEncodingException("Exception");
			}
			this.interfacetype=value_split[0];
			this.process_number=value_split[1];
			this.network_event_ts=value_split[2];
			this.imsi=value_split[3];
			// if the field is empty and you cast it to Int you might get error. Hence the exception handling
			try{
				this.imei=Integer.parseInt(value_split[4]);
			}
			catch(NumberFormatException ex){
				this.imei=0;
			}
			try{
				this.lac=Integer.parseInt(value_split[5]);
			}
			catch(NumberFormatException ex){
				this.lac=0;
			}
			try{
				this.rac=Integer.parseInt(value_split[6]);
			}
			catch(NumberFormatException ex){
				this.rac=0;
			}
			try{
				this.tac=Integer.parseInt(value_split[7]);
			}
			catch(NumberFormatException ex){
				this.tac=0;
			}
			try{
				this.cell=Integer.parseInt(value_split[8]);
			}
			catch(NumberFormatException ex){
				this.cell=0;
			}
			this.transactiontype=value_split[9];
			this.transactionsubtype=value_split[10];
			this.error_code1=value_split[11];
			this.error_code2=value_split[12];
			this.error_code3=value_split[13];
			this.error_code4=value_split[14];
			this.error_code5=value_split[15];
			this.event_date=value_split[16];
			this.ipadress=value_split[17];
		}
		catch(Exception e){
			throw new UnsupportedEncodingException("Exception");
		}
	}

	public String getInterfacetype() {
		return interfacetype;
	}

	public String getProcess_number() {
		return process_number;
	}

	public String getNetwork_event_ts() {
		return network_event_ts;
	}

	public String getImsi() {
		return imsi;
	}

	public int getImei() {
		return imei;
	}

	public int getLac() {
		return lac;
	}

	public int getRac() {
		return rac;
	}

	public int getTac() {
		return tac;
	}

	public int getCell() {
		return cell;
	}

	public String getTransactiontype() {
		return transactiontype;
	}

	public String getTransactionsubtype() {
		return transactionsubtype;
	}

	public String getError_code1() {
		return error_code1;
	}

	public String getError_code2() {
		return error_code2;
	}

	public String getError_code3() {
		return error_code3;
	}

	public String getError_code4() {
		return error_code4;
	}

	public String getError_code5() {
		return error_code5;
	}

	public String getEvent_date() {
		return event_date;
	}

	public String getIpadress() {
		return ipadress;
	}

	public void setInterfacetype(String interfacetype) {
		this.interfacetype = interfacetype;
	}

	public void setProcess_number(String process_number) {
		this.process_number = process_number;
	}

	public void setNetwork_event_ts(String network_event_ts) {
		this.network_event_ts = network_event_ts;
	}

	public void setImsi(String imsi) {
		this.imsi = imsi;
	}

	public void setImei(int imei) {
		this.imei = imei;
	}

	public void setLac(int lac) {
		this.lac = lac;
	}

	public void setRac(int rac) {
		this.rac = rac;
	}

	public void setTac(int tac) {
		this.tac = tac;
	}

	public void setCell(int cell) {
		this.cell = cell;
	}

	public void setTransactiontype(String transactiontype) {
		this.transactiontype = transactiontype;
	}

	public void setTransactionsubtype(String transactionsubtype) {
		this.transactionsubtype = transactionsubtype;
	}

	public void setError_code1(String error_code1) {
		this.error_code1 = error_code1;
	}

	public void setError_code2(String error_code2) {
		this.error_code2 = error_code2;
	}

	public void setError_code3(String error_code3) {
		this.error_code3 = error_code3;
	}

	public void setError_code4(String error_code4) {
		this.error_code4 = error_code4;
	}

	public void setError_code5(String error_code5) {
		this.error_code5 = error_code5;
	}

	public void setEvent_date(String event_date) {
		this.event_date = event_date;
	}

	public void setIpadress(String ipadress) {
		this.ipadress = ipadress;
	}

	public DateTime getNetworkEventDate(){
		//Date is in format 2015-08-14 13:47:10.941, uses jodatime to create a date.
		return DateTime.parse(this.network_event_ts,DateTimeFormat.forPattern("yyyy-MM-dd HH:mm:ss.SSS"));

	}

}
