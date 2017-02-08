
package bgc.services.bealert.v1;

/**
 * Please modify this class to meet your needs
 * This class is not complete
 */

import java.io.File;
import java.net.MalformedURLException;
import java.net.URL;
import javax.xml.namespace.QName;
import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebResult;
import javax.jws.WebService;
import javax.jws.soap.SOAPBinding;
import javax.xml.bind.annotation.XmlSeeAlso;

/**
 * This class was generated by Apache CXF 3.1.6
 * 2016-07-04T14:13:13.959+02:00
 * Generated source version: 3.1.6
 * 
 */
public final class BeAlertPortType_BeAlert11SOAPPort_Client {

    private static final QName SERVICE_NAME = new QName("urn:v1.bealert.services.bgc", "BeAlert-1.1-Service");

    private BeAlertPortType_BeAlert11SOAPPort_Client() {
    }

    public static void main(String args[]) throws java.lang.Exception {
        URL wsdlURL = BeAlert11Service.WSDL_LOCATION;
        if (args.length > 0 && args[0] != null && !"".equals(args[0])) { 
            File wsdlFile = new File(args[0]);
            try {
                if (wsdlFile.exists()) {
                    wsdlURL = wsdlFile.toURI().toURL();
                } else {
                    wsdlURL = new URL(args[0]);
                }
            } catch (MalformedURLException e) {
                e.printStackTrace();
            }
        }
      
        BeAlert11Service ss = new BeAlert11Service(wsdlURL, SERVICE_NAME);
        BeAlertPortType port = ss.getBeAlert11SOAPPort();  
        
        {
        System.out.println("Invoking getGis...");
        bgc.services.bealert.v1.RequestDataGetGisDataType _getGis_getGisRequestMessagePart = null;
        bgc.objects.vss.context.v4.Context _getGis_context = null;
        try {
            bgc.services.bealert.v1.ResponseDataGetGisDataType _getGis__return = port.getGis(_getGis_getGisRequestMessagePart, _getGis_context);
            System.out.println("getGis.result=" + _getGis__return);

        } catch (FunctionalFaultMessage e) { 
            System.out.println("Expected exception: FunctionalFaultMessage has occurred.");
            System.out.println(e.toString());
        } catch (TechnicalFaultMessage e) { 
            System.out.println("Expected exception: TechnicalFaultMessage has occurred.");
            System.out.println(e.toString());
        }
            }
        {
        System.out.println("Invoking checkService...");
        bgc.objects.vss.checkservice.v1.RequestDataCheckServiceType _checkService_checkServiceRequestMessagePart = null;
        bgc.objects.vss.context.v4.Context _checkService_context = null;
        try {
            bgc.objects.vss.checkservice.v1.ResponseDataCheckServiceType _checkService__return = port.checkService(_checkService_checkServiceRequestMessagePart, _checkService_context);
            System.out.println("checkService.result=" + _checkService__return);

        } catch (FunctionalFaultMessage e) { 
            System.out.println("Expected exception: FunctionalFaultMessage has occurred.");
            System.out.println(e.toString());
        } catch (TechnicalFaultMessage e) { 
            System.out.println("Expected exception: TechnicalFaultMessage has occurred.");
            System.out.println(e.toString());
        }
            }
        {
        System.out.println("Invoking getRlts...");
        bgc.services.bealert.v1.RequestDataGetRltsDataType _getRlts_getRltsRequestMessagePart = null;
        bgc.objects.vss.context.v4.Context _getRlts_context = null;
        try {
            bgc.services.bealert.v1.ResponseDataGetRltsDataType _getRlts__return = port.getRlts(_getRlts_getRltsRequestMessagePart, _getRlts_context);
            System.out.println("getRlts.result=" + _getRlts__return);

        } catch (FunctionalFaultMessage e) { 
            System.out.println("Expected exception: FunctionalFaultMessage has occurred.");
            System.out.println(e.toString());
        } catch (TechnicalFaultMessage e) { 
            System.out.println("Expected exception: TechnicalFaultMessage has occurred.");
            System.out.println(e.toString());
        }
            }

        System.exit(0);
    }

}
