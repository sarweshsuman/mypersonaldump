package com.proximus.rtls.libs;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.zip.GZIPOutputStream;

import org.apache.log4j.Logger;

import com.jcraft.jsch.ChannelSftp;
import com.jcraft.jsch.JSch;
import com.jcraft.jsch.JSchException;
import com.jcraft.jsch.Session;
import com.jcraft.jsch.SftpException;
import com.proximus.rtls.exception.RTLSException;

public class RTLSExportUtilities {
	
	Logger logger = Logger.getLogger(RTLSExportUtilities.class);
	ArrayList<String> logger_buffer = new ArrayList<String>();
	JSch jsch = new JSch();
	String host;
	String username;
	String password;
	File privKey;
	Session session;
	ChannelSftp sftp;
	
	public RTLSExportUtilities(String host,String uname,String pssword) throws JSchException{
		long starttime = System.currentTimeMillis();
		this.host=host;
		this.username=uname;
		this.password=pssword;
		this.session=this.jsch.getSession(this.username,this.host,22);
		this.session.setPassword(this.password);
		this.session.setConfig("StrictHostKeyChecking", "no");
		this.session.connect();
		this.sftp = (ChannelSftp) this.session.openChannel("sftp");
		this.sftp.connect();
		long endtime = System.currentTimeMillis();
		this.logger_buffer.add("RTLSExportUtilities connected to export destination within "+(endtime-starttime)+"ms");
	}
	public RTLSExportUtilities(String host,String uname,File key) throws RTLSException,JSchException{
		long starttime = System.currentTimeMillis();		
		this.host=host;
		this.username=uname;
		this.privKey=key;
		if (!key.exists()){
			throw new RTLSException("private key not found");
		}
		jsch.addIdentity(this.privKey.toString());
		this.session=this.jsch.getSession(this.username,this.host,22);
		this.session.setConfig("StrictHostKeyChecking", "no");
		this.session.connect();
		this.sftp = (ChannelSftp) this.session.openChannel("sftp");
		this.sftp.connect();
		long endtime = System.currentTimeMillis();
		this.logger_buffer.add("RTLSExportUtilities connected to export destination within "+(endtime-starttime)+"ms");		
	}
	
	public String gzip(String sourceFile) throws IOException {
		long starttime = System.currentTimeMillis();
		
		byte[] buffer = new byte[1024];
		FileOutputStream fileOutputStream =new FileOutputStream(sourceFile+".gzip");
		GZIPOutputStream gzipOuputStream = new GZIPOutputStream(fileOutputStream);
		FileInputStream fileInput = new FileInputStream(sourceFile);
		int bytes_read;
		while ((bytes_read = fileInput.read(buffer)) > 0) {
			 gzipOuputStream.write(buffer, 0, bytes_read);
		}
		fileInput.close();
		gzipOuputStream.finish();
		gzipOuputStream.close();
		long endtime = System.currentTimeMillis();		
		this.logger_buffer.add("RTLSExportUtilities gzipped in "+(endtime-starttime)+"ms");
		return sourceFile+".gzip";
	}
	
	public void cwd_sftp(String remotedir) throws SftpException {
		long starttime = System.currentTimeMillis();
		this.sftp.cd(remotedir);
		long endtime = System.currentTimeMillis();		
		this.logger_buffer.add("RTLSExportUtilities changed working directory in "+(endtime-starttime)+"ms");		
	}
	public void get_sftp(String remotefile,String localfile) throws SftpException {
		long starttime = System.currentTimeMillis();		
		this.sftp.get(remotefile, localfile);
		long endtime = System.currentTimeMillis();				
		this.logger_buffer.add("RTLSExportUtilities got the file within "+(endtime-starttime)+"ms");
	}	
	public void put_sftp(String localfile,String remotefile) throws SftpException {
		long starttime = System.currentTimeMillis();		
		this.sftp.put(localfile, remotefile);
		long endtime = System.currentTimeMillis();	
		this.logger_buffer.add("RTLSExportUtilities exported the file in "+(endtime-starttime)+"ms");
	}
	public void close(){
		this.sftp.exit();
		this.session.disconnect();
		for(String msg : this.logger_buffer){
			this.logger.debug(msg);
		}
	}
}
