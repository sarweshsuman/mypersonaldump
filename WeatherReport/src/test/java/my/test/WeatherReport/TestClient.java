package my.test.WeatherReport;

import java.text.SimpleDateFormat;  
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.List;  
  

import javax.xml.datatype.DatatypeFactory;
import javax.xml.datatype.XMLGregorianCalendar;
import junit.framework.TestCase;  

import net.webservicex.*;

public class TestClient extends TestCase {  
      
    public void testClient() throws Exception {
    	GlobalWeather wthr = new GlobalWeather();
    	GlobalWeatherSoap soap = wthr.getGlobalWeatherSoap();
    	System.out.println(soap.getCitiesByCountry("INDIA"));
    }  
  
} 