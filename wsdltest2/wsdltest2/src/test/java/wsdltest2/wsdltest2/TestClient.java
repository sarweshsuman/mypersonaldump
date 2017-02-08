package wsdltest2.wsdltest2;

import java.util.Properties;

import junit.framework.TestCase;
import net.webservicex.GlobalWeather;
import net.webservicex.GlobalWeatherSoap;

public class TestClient extends TestCase {

    public void testClient() throws Exception {
    	/*
    	Properties props = new Properties();
    	props.put("java.home", "C:\\Program Files\\Java\\jdk1.8.0_77");
    	props.put("java.net.useSystemProxies", "true");
    	System.setProperties(props);
    	*/
    	GlobalWeather wthr = new GlobalWeather();
    	GlobalWeatherSoap soap = wthr.getGlobalWeatherSoap();
    	System.out.println(soap.getCitiesByCountry("INDIA"));
    }

}