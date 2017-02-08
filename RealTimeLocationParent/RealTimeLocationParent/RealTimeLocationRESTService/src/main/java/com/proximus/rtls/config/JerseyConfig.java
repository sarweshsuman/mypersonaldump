package com.proximus.rtls.config;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashSet;
import java.util.Properties;
import java.util.Set;

import javax.ws.rs.core.Application;
import com.proximus.rtls.requesthandlers.CellIdRequestHandler;

public class JerseyConfig extends Application{
	private Set<Object> singletons = new HashSet<Object>();

	public static final String PropertiesFile = "config.properties";
	public static Properties props = new Properties();

	private Properties readProperties(){
		InputStream inputStream = getClass().getClassLoader().getResourceAsStream(PropertiesFile);
		if (inputStream != null){
			try{
				props.load(inputStream);
			}
			catch (IOException e){

			}
		}
		return props;
	}
	@Override
	public Set<Class<?>> getClasses(){
		readProperties();
		Set<Class<?>> rootResources = new HashSet<Class<?>>();
		rootResources.add(CellIdRequestHandler.class);
		return rootResources;
	}

	public JerseyConfig() {
		singletons.add(new CellIdRequestHandler());
	}

	@Override
	public Set<Object> getSingletons() {
		return singletons;
	}
}
