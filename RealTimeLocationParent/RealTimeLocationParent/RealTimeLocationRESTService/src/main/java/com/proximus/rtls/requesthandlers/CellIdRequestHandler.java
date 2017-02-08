package com.proximus.rtls.requesthandlers;

import java.util.ArrayList;
import java.util.List;

import javax.servlet.ServletContext;
import javax.ws.rs.FormParam;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.MediaType;

import org.apache.log4j.Logger;

import com.proximus.rtls.config.JerseyConfig;
import com.proximus.rtls.exception.RTLSException;
import com.proximus.rtls.libs.RTLSResponse;
import com.proximus.rtls.libs.RTLSServletContextListener;
import com.proximus.rtls.main.RealTimeLocationStoreASynchronous;
import com.proximus.rtls.main.RealTimeLocationStoreSynchronous;
import com.proximus.rtls.redis.libs2.Cell;
import com.proximus.rtls.redis.libs2.NCell;
import com.proximus.rtls.redis.libs2.StormThread;

@Path("service")
public class CellIdRequestHandler {


	RealTimeLocationStoreSynchronous rtls_main ;
	@Context ServletContext context;
	RTLSServletContextListener contextListener;
	Logger logger = Logger.getLogger(CellIdRequestHandler.class);

	@GET
	@Path("imsitomsisdn")
	@Produces(MediaType.TEXT_PLAIN)
	public String imsitomsisdn_list(){
		this.logger.debug("Received request to return imsi to msisdn mapping as list");
		this.contextListener=RTLSServletContextListener.getInstance(this.context);
		return this.contextListener.mapping.imsitomsisdn.toString();
	}
	//Get request for all cellids , output file will be sent to remote location
	@GET
	@Path("cellids_ftp")
	@Produces(MediaType.APPLICATION_XML)
	public RTLSResponse getAllMsisdnWithinAllCellId_FTP(){
		this.logger.debug("Recevied request to send via ftp all cellids with all msisdns within it");
		this.contextListener=RTLSServletContextListener.getInstance(this.context);
		try{
			RealTimeLocationStoreASynchronous rtls_async = new RealTimeLocationStoreASynchronous(
					JerseyConfig.props.getProperty("rtls.temp.dir"),
					JerseyConfig.props.getProperty("rtls.redis.server"),
					Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.port")),
					JerseyConfig.props.getProperty("rtls.export.server"),
					JerseyConfig.props.getProperty("rtls.export.username"),
					JerseyConfig.props.getProperty("rtls.export.password"),
					JerseyConfig.props.getProperty("rtls.export.directory"),
					JerseyConfig.props.getProperty("rtls.import.directory"),
					this.contextListener);

			Long requestId = rtls_async.getRequestId();

			RTLSResponse response=new RTLSResponse(requestId,rtls_async.getFileName());

			if(rtls_async != null){
				Thread t = new Thread(rtls_async,"RealTimeLocationStoreASynchronous-"+requestId);
				t.start();
				return response;
			}
			else {
				// throw error that this class is not properly initialized
				response.setErrorcode(2);
				response.setErrorDescription("Problem in Initialization");
				return response;
			}
		}
		catch(Exception e){
			this.logger.debug("Exception seen "+e.getMessage());
			RTLSResponse response = new RTLSResponse();
			response.setErrorcode(3);
			response.setErrorDescription(e.getMessage());
			return response;
		}

	}

	//ASync Post Request with either cellids or remote filename , output file will be loaded into remote location
	@POST
	@Path("cellids_ftp")
	@Produces(MediaType.APPLICATION_XML)
	public RTLSResponse getAllMsisdnWithinNCellId_FTP(@FormParam("cellids") String cellids, @FormParam("IFileName") String filename , @FormParam("requestId") String requestid){
		this.logger.debug("Recevied request to send via ftp for request id "+requestid);
		this.contextListener=RTLSServletContextListener.getInstance(this.context);
		try{
			RealTimeLocationStoreASynchronous rtls_async = new RealTimeLocationStoreASynchronous(
					JerseyConfig.props.getProperty("rtls.temp.dir"),
					JerseyConfig.props.getProperty("rtls.redis.server"),
					Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.port")),
					JerseyConfig.props.getProperty("rtls.export.server"),
					JerseyConfig.props.getProperty("rtls.export.username"),
					JerseyConfig.props.getProperty("rtls.export.password"),
					JerseyConfig.props.getProperty("rtls.export.directory"),
					JerseyConfig.props.getProperty("rtls.import.directory"),
					this.contextListener);

			rtls_async.requestIdFromRequestor=Long.parseLong(requestid);

			RTLSResponse response=new RTLSResponse(rtls_async.requestIdFromRequestor,rtls_async.getFileName());

			String[] cellids_array;
			if (cellids != null ){
				String new_cellids = cellids.replaceAll("-",":");
				//String new_cellids = new_cellids1.replaceAll(",",",cell:");
				//new_cellids = "cell:"+new_cellids;
				//this.logger.debug("cellid line as "+new_cellids);
				cellids_array = new_cellids.split(",");
				rtls_async.cellidsdefined=true;
				rtls_async.cellids=cellids_array;
			}
			else if ( filename != null ) {
				rtls_async.importfilename=filename;
				rtls_async.readfromremote=true;
			}
			else {
				response.setErrorcode(1);
				response.setErrorDescription("Parameter in request is incorrect");
				return response;
			}

			if(rtls_async != null){
				Thread t = new Thread(rtls_async,"RealTimeLocationStoreASynchronous-"+requestid);
				t.start();
				return response;
			}
			else {
				// throw error that this class is not properly initialized
				response.setErrorcode(2);
				response.setErrorDescription("Problem in Initialization");
				return response;
			}
		}
		catch(Exception e){
			this.logger.debug("Exception seen "+e.getMessage());
			RTLSResponse response = new RTLSResponse();
			response.setErrorcode(3);
			response.setErrorDescription(e.getMessage());
			return response;
		}
	}

	//Get request with one cellid-lac
	//cellids/234800/2445
	//cellids/celldid/lac
	@GET
	@Path("cellids/{cellid:[0-9]+}/{lac:[0-9]+}")
	@Produces(MediaType.APPLICATION_XML)
	public RTLSResponse getAllMsisdnWithinACellId_XML(@PathParam("cellid") Long cellid,@PathParam("lac") Long lac){
		this.logger.debug("Recevied request to send all msisdns within cell "+cellid+":"+lac);
		this.contextListener=RTLSServletContextListener.getInstance(this.context);
		try{
			this.rtls_main = new RealTimeLocationStoreSynchronous(JerseyConfig.props.getProperty("rtls.redis.server"),Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.port")),Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.read.timeout","5000")),this.contextListener);
			RTLSResponse response = new RTLSResponse();
			if(this.rtls_main != null){
				try{
					String new_cell_id_2 = cellid+":"+lac;
					Cell return_value=this.rtls_main.handleCellIdRequest_XML(new_cell_id_2);
					this.rtls_main.exit();
					List<Cell> cell_list = new ArrayList<Cell>();
					cell_list.add(return_value);
					response.setCelldetails(cell_list);
					return response;
				}
				catch(RTLSException e){
					this.rtls_main.exit();
					this.logger.debug("Exception seen "+e.getMessage());
					response.setErrorcode(3);
					response.setErrorDescription(e.getMessage());
					return response;
				}
			}
			else {
				// throw error that this class is not properly initialized
				response.setErrorcode(2);
				response.setErrorDescription("Problem in Initialization");
				return response;
			}
		}catch(Exception e){
			this.logger.debug("Exception seen "+e.getMessage());
			RTLSResponse response = new RTLSResponse();
			response.setErrorcode(3);
			response.setErrorDescription(e.getMessage());
			return response;
		}
	}

	@GET
	@Path("celllist")
	@Produces(MediaType.APPLICATION_XML)
	public List<NCell> getCellList_XML() throws RTLSException{
		this.logger.debug("Recevied request to send all cell as list");
		this.contextListener=RTLSServletContextListener.getInstance(this.context);
		try{
			this.rtls_main = new RealTimeLocationStoreSynchronous(JerseyConfig.props.getProperty("rtls.redis.server"),Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.port")),Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.read.timeout","5000")),this.contextListener);
			if(this.rtls_main != null){
				try{
					List<NCell> ncell = this.rtls_main.returnCellList_XML();
					this.rtls_main.exit();
					System.out.println(ncell);
					return ncell;
				}
				catch(Exception e){
					this.rtls_main.exit();
					throw new RTLSException(e.getMessage());
				}
			}
			else {
				// throw error that this class is not properly initialized
				throw new RTLSException("RTLS Not initialized properly");
			}
		}catch(Exception e){
			this.logger.debug("Exception seen "+e.getMessage());
			throw new RTLSException(e.getMessage());
		}
	}

	@GET
	@Path("threadinfo")
	@Produces(MediaType.APPLICATION_XML)
	public List<StormThread> getThreadInfo_XML() throws RTLSException{
		this.logger.debug("Recevied request to send storm bolt thread info");
		this.contextListener=RTLSServletContextListener.getInstance(this.context);
		try{
			this.rtls_main = new RealTimeLocationStoreSynchronous(JerseyConfig.props.getProperty("rtls.redis.server"),Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.port")),Integer.parseInt(JerseyConfig.props.getProperty("rtls.redis.read.timeout","5000")),this.contextListener);
			if(this.rtls_main != null){
				try{
					List<StormThread> list = this.rtls_main.returnThreadInfo_XML();
					this.rtls_main.exit();
					return list;
				}
				catch(Exception e){
					this.rtls_main.exit();
					throw new RTLSException(e.getMessage());
				}
			}
			else {
				// throw error that this class is not properly initialized
				throw new RTLSException("RTLS Not initialized properly");
			}
		}catch(Exception e){
			this.logger.debug("Exception seen "+e.getMessage());
			throw new RTLSException(e.getMessage());
		}
	}
}
