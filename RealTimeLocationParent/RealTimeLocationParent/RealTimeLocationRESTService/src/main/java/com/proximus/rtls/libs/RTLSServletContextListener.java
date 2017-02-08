package com.proximus.rtls.libs;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Properties;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import org.apache.log4j.Logger;

import com.proximus.rtls.redis.libs2.LoadImsiMsisdnMapping;

public class RTLSServletContextListener implements ServletContextListener{

	private static final String ATTRIBUTE_NAME="rtlscontext";
	private static final String LOGGER="logger";
	public Properties props = new Properties();
	public ArrayList<String> logger_buffer = new ArrayList<String>();

	ScheduledExecutorService scheduledExecutorService;
	ScheduledFuture scheduledFuture;
	public static LoadImsiMsisdnMapping mapping;

	Logger logger = Logger.getLogger(RTLSServletContextListener.class);

	@Override
	public void contextDestroyed(ServletContextEvent arg0) {
		System.out.println("ServletContextListener destroyed");
		this.scheduledExecutorService.shutdown();
		this.mapping = null;
		this.logger=null;
	}

        //Run this before web application is started
	@Override
	public void contextInitialized(ServletContextEvent arg0) {
		try{
			this.props.load(Thread.currentThread().getContextClassLoader().getResourceAsStream("config.properties"));
		}
		catch(Exception e){
			this.logger.debug("Exception in context listener " + e.getMessage());
			System.out.println("Exception in context listener " + e.getMessage());
			System.exit(1);
		}
		int interval = Integer.parseInt(this.props.getProperty("rtls.refresh.imsi.msisdn.mapping.interval","10"));
		int delay = Integer.parseInt(this.props.getProperty("rtls.refresh.imsi.msisdn.mapping.delay","2"));

    	this.mapping = new LoadImsiMsisdnMapping(this.props.getProperty("rtls.redis.server"),
				Integer.parseInt(this.props.getProperty("rtls.redis.port")),Integer.parseInt(this.props.getProperty("rtls.redis.read.timeout","50000")));


		 this.scheduledExecutorService =
		        Executors.newScheduledThreadPool(1);

		 this.scheduledFuture =
		    scheduledExecutorService.scheduleAtFixedRate(new Runnable() {
				@Override
				public void run() {
					// TODO Auto-generated method stub
		            //System.out.println("Executed!");
		            RTLSServletContextListener.mapping.load();
				}
		    },
		    delay,interval,
		    TimeUnit.SECONDS);

		arg0.getServletContext().setAttribute(ATTRIBUTE_NAME, this);
		System.out.println("ServletContextListener started");

	}

	public static RTLSServletContextListener getInstance(ServletContext context){
		return (RTLSServletContextListener)context.getAttribute(ATTRIBUTE_NAME);
	}
}
