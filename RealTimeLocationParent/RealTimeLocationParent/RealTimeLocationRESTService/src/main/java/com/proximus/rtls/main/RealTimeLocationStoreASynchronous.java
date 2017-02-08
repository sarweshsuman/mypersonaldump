package com.proximus.rtls.main;


import bgc.objects.vss.context.v4.Context;
import bgc.services.bealert.v1.BeAlert11Service;
import bgc.services.bealert.v1.BeAlertPortType;
import bgc.services.bealert.v1.FunctionalFaultMessage;
import bgc.services.bealert.v1.RequestDataGetRltsDataType;
import bgc.services.bealert.v1.ResponseDataGetRltsDataType;
import bgc.services.bealert.v1.TechnicalFaultMessage;

import com.jcraft.jsch.JSchException;
import com.jcraft.jsch.SftpException;
import com.proximus.rtls.exception.RTLSException;
import com.proximus.rtls.libs.RTLSExportUtilities;
import com.proximus.rtls.libs.RTLSServletContextListener;
import com.proximus.rtls.redis.libs2.ReadCellList;
import com.proximus.rtls.redis.libs2.RedisConnectionManager;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.net.URL;
import java.nio.file.Paths;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Stack;

import javax.xml.namespace.QName;

import org.apache.log4j.Logger;

public class RealTimeLocationStoreASynchronous implements Runnable{

		RTLSServletContextListener contextListener;

	    private static final QName SERVICE_NAME = new QName("urn:v1.bealert.services.bgc", "BeAlert-1.1-Service");
		URL wsdlLocation;
		BeAlert11Service service;
		BeAlertPortType portType;
		RequestDataGetRltsDataType rtlsDataType = new RequestDataGetRltsDataType();
		Context rtlsContext;



		String redisserver;
		int redisport;

		ReadCellList readcellList;
		Logger logger = Logger.getLogger(RealTimeLocationStoreASynchronous.class);
		ArrayList<String> logging_buffer;

		RTLSExportUtilities export;

		Date dt = new Date();
		SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMdd");

		String exportfilename;
		long requestId;
		public long requestIdFromRequestor;

		String temp_dirName;

		String destinationServer;
		String userName;
		String password;

		FileWriter fw;
		BufferedWriter bw;
		Integer bufferSize = 24680064;

		public String[] cellids;
		public boolean cellidsdefined=false;

		public String importfilename;
		public boolean readfromremote=false;

		public String exportDir;
		public String importDir;

		// Number of cells to process at one time
		int bufferedProcessing=5000;
		// Number of threads to invoke at one time
		int parallelThreads=10;

		int timeout;

		/*
		public RealTimeLocationStoreASynchronous(String temp_dirName,String destinationServer,String userName,String password,String exportDir, String importDir , RTLSServletContextListener contextListener ) throws IOException,RTLSException{
			this.exportDir=exportDir;
			this.importDir=importDir;
			this.redisserver="localhost";
			this.redisport=6379;
			this.contextListener=contextListener;
			this.readcellList = new ReadCellList(new RedisConnectionManager("localhost"),this.contextListener);
			this.requestId=dt.getTime();
			this.exportfilename = "RTLS_"+sdf.format(dt).toString()+"_"+this.requestId;
			this.temp_dirName=temp_dirName;
			this.fw=new FileWriter(Paths.get(this.temp_dirName,this.exportfilename+".temp").toString(),true);
			this.bw=new BufferedWriter(this.fw,this.bufferSize);
			this.destinationServer=destinationServer;
			this.userName=userName;
			this.password=password;
			this.timeout=50000;
			//this.logger.debug("initialized");
		}
		*/
		public RealTimeLocationStoreASynchronous(String temp_dirName,String redisserver,int redisport,String destinationServer,String userName,String password, String exportDir , String importDir , RTLSServletContextListener contextListener ) throws IOException,RTLSException{
			this.exportDir=exportDir;
			this.importDir=importDir;
			this.redisserver=redisserver;
			this.redisport=redisport;
			this.contextListener=contextListener;
			this.timeout=Integer.parseInt(this.contextListener.props.getProperty("rtls.redis.read.timeout"));
			this.readcellList = new ReadCellList(new RedisConnectionManager(redisserver,redisport,timeout),this.contextListener);
			this.requestId=dt.getTime();
			this.exportfilename = "RTLS_"+sdf.format(dt).toString()+"_"+this.requestId;
			this.temp_dirName=temp_dirName;
			this.fw=new FileWriter(Paths.get(this.temp_dirName,this.exportfilename+".temp").toString(),true);
			this.bw=new BufferedWriter(this.fw,this.bufferSize);
			this.destinationServer=destinationServer;
			this.userName=userName;
			this.password=password;
			this.bufferedProcessing=Integer.parseInt(this.contextListener.props.getProperty("rtls.processing.batch","10000"));
			this.parallelThreads=Integer.parseInt(this.contextListener.props.getProperty("rtls.processing.parallel.threads","6"));
			String wsdlFileName=this.contextListener.props.getProperty("orchestrator.notification.wsdl");
			if(wsdlFileName == null ){
				wsdlFileName = Thread.currentThread().getContextClassLoader().getSystemResource("BeAlert-1.1-standard-http_binding.wsdl").toString();
			}
			this.wsdlLocation=new URL(wsdlFileName);
			this.service=new BeAlert11Service(this.wsdlLocation, SERVICE_NAME);
			this.portType=this.service.getBeAlert11SOAPPort();
			this.logging_buffer=this.contextListener.logger_buffer;
			//this.logger.debug("initialized");
		}
		public String getFileName(){
				return this.exportfilename;
		}
		public long getRequestId(){
			return this.requestId;
		}
		public void exit() throws IOException, SftpException, JSchException{
			this.readcellList.pipe.close();
			this.readcellList.connection.close();
			this.readcellList=null;
			this.bw.flush();
			this.bw.close();
			this.export = new RTLSExportUtilities(this.destinationServer,this.userName,this.password);
			this.export.put_sftp(Paths.get(this.temp_dirName, this.exportfilename+".temp").toString(), Paths.get(this.exportDir,this.exportfilename).toString());
			this.export.close();

			this.rtlsDataType.setErrorCode("0");
			this.rtlsDataType.setErrorMsg("OK");
			this.rtlsDataType.setFileName(this.exportfilename);
			this.rtlsDataType.setReqId(String.valueOf(this.requestId));

	        try {
	            ResponseDataGetRltsDataType _getRlts__return = this.portType.getRlts(this.rtlsDataType,this.rtlsContext);
	            this.logging_buffer.add("Recevied Response from Orchestrator Error Code:"+_getRlts__return.getErrorCode() + " Error Message :"+_getRlts__return.getErrorMsg());

	        } catch (FunctionalFaultMessage e) {
	            this.logging_buffer.add("FunctionalFaultMessage exception recevied from Orchestrator "+e.getMessage());
	        } catch (TechnicalFaultMessage e) {
	            this.logging_buffer.add("TechnicalFaultMessage exception recevied from Orchestrator "+e.getMessage());
	        }

			for(String msg : this.logging_buffer){
				this.logger.debug(msg);
			}
			this.logging_buffer.clear();
			this.logger.debug("exiting");

		}

		public void cleanup(){

		}

		public void run() {
			long starttime = System.currentTimeMillis();
			try {

				//logging_buffer.clear();
				logging_buffer.add("Starting thread with cellid(boolean)=" + this.cellidsdefined + " readfromfile(boolean)=" + this.readfromremote + " remote file to read from=" + this.importfilename);

				String[] celllist;
				if(this.cellidsdefined == true){
					celllist = this.cellids;
				}
				else if ( this.readfromremote == true){
					celllist = getCellIdsFromRemoteFile();
				}
				else {
					celllist = this.readcellList.getAllCellName();
				}

				logging_buffer.add("Total Number of cells to process "+celllist.length);
				logging_buffer.add("Cell to process ");
				for(String cell:celllist){
					logging_buffer.add(cell);
				}
				//this.logger.trace("Total Number of cells to process "+celllist.length);

				ArrayList<String> batched_cell = new ArrayList<String>();
				Stack<Thread> total_threads = new Stack<Thread>();
				Stack<Thread> wait_until_complete = new Stack<Thread>();
				int counter=0;

				for(int i = 0 ; i<celllist.length ; i++){
					String arr[] = celllist[i].split(":");
					if(arr.length == 3)
						batched_cell.add(celllist[i].split(":")[1]+":"+celllist[i].split(":")[2]);
					else if (arr.length == 2)
						batched_cell.add(celllist[i]);
					else
						continue;
					counter++;
					if(counter == this.bufferedProcessing ){
						ReadCellList readcellList_threaded = new ReadCellList(new RedisConnectionManager(this.redisserver,this.redisport,timeout),this.contextListener);
						readcellList_threaded.start("RTLS AsyncReadRedis-"+i,batched_cell.toArray(new String[batched_cell.size()]), this.bw);
						Thread t = new Thread(readcellList_threaded,"RTLS AsyncReadRedis-"+i);
						total_threads.push(t);
						counter=0;
						batched_cell.clear();
					}
				}
				if(batched_cell.isEmpty() == false){
					ReadCellList readcellList_threaded = new ReadCellList(new RedisConnectionManager(this.redisserver,this.redisport,timeout),this.contextListener);
					readcellList_threaded.start("RTLS AsyncReadRedisLast",batched_cell.toArray(new String[batched_cell.size()]), this.bw);
					Thread t = new Thread(readcellList_threaded,"RTLS AsyncReadRedisLast");
					total_threads.push(t);
					counter=0;
					batched_cell.clear();
				}
				counter = 0;
				while(total_threads.isEmpty() == false ){
					Thread t = total_threads.pop();
					t.start();
					wait_until_complete.push(t);
					counter++;
					if(counter == this.parallelThreads){
						logging_buffer.add("Thread "+counter+" started Now waiting");
						while(wait_until_complete.isEmpty() == false){
							Thread t2 = wait_until_complete.pop();
							t2.join();
							logging_buffer.add("1 Thread completed starting another");
							counter--;
							break;
						}
					}
				}
				logging_buffer.add("Waiting for remaining thread to complete ");
				//this.logger.trace("Waiting for remaining thread to complete ");
				while(wait_until_complete.isEmpty() == false){
					Thread t2 = wait_until_complete.pop();
					t2.join();
				}
			/*
			}catch(RTLSException e){
				this.logging_buffer.add("Recevied exception "+e.getMessage());
			}
			catch(IOException e){
				this.logging_buffer.add("Recevied exception "+e.getMessage());
			}
			catch(Exception e){
				this.logging_buffer.add("Recevied exception "+e.getMessage());
			}
			try{
			*/
				long endtime = System.currentTimeMillis();
				logging_buffer.add("Thread run complete in " + (endtime-starttime) + "ms");
				this.exit();
			}catch(Exception e){
				this.logging_buffer.add("Recevied exception "+e.getMessage());

				try{
					this.readcellList.pipe.close();
					this.readcellList.connection.close();
					this.readcellList=null;
					this.bw.flush();
					this.bw.close();
				}
				catch(IOException e1){

				}

				this.rtlsDataType.setErrorCode("3");
				this.rtlsDataType.setErrorMsg(e.getMessage());
				this.rtlsDataType.setFileName(this.exportfilename);
				this.rtlsDataType.setReqId(String.valueOf(this.requestId));

		        try {
		            ResponseDataGetRltsDataType _getRlts__return = this.portType.getRlts(this.rtlsDataType,this.rtlsContext);
		            this.logging_buffer.add("Recevied Response from Orchestrator Error Code:"+_getRlts__return.getErrorCode() + " Error Message :"+_getRlts__return.getErrorMsg());
		        } catch (FunctionalFaultMessage e1) {
		        	this.logging_buffer.add("FunctionalFaultMessage exception recevied from Orchestrator "+e1.getMessage());
		        } catch (TechnicalFaultMessage e1) {
		        	this.logging_buffer.add("TechnicalFaultMessage exception recevied from Orchestrator "+e1.getMessage());
		        }

				for(String msg : this.logging_buffer){
					this.logger.debug(msg);
				}
				this.logging_buffer.clear();

			}
		}
		public String[] getCellIdsFromRemoteFile() throws IOException, SftpException, JSchException{
			RTLSExportUtilities reader = new RTLSExportUtilities(this.destinationServer,this.userName,this.password);
			reader.get_sftp(Paths.get(this.importDir,this.importfilename).toString(), Paths.get(this.temp_dirName,this.importfilename).toString());
			reader.close();
			FileReader fr = new FileReader(Paths.get(this.temp_dirName,this.importfilename).toString());
			BufferedReader br = new BufferedReader(fr);
			//String complete_line="";
			ArrayList<String> complete_line = new ArrayList<String>();
			String line="";
			while((line=br.readLine()) != null){
				line=line.replace("-", ":");
				complete_line.add(line);
			}
			//complete_line=complete_line.substring(1,complete_line.length());
			br.close();
			fr.close();
			return complete_line.toArray(new String[complete_line.size()]);
		}
}
