
package bgc.services.bealert.v1;

import javax.xml.bind.JAXBElement;
import javax.xml.bind.annotation.XmlElementDecl;
import javax.xml.bind.annotation.XmlRegistry;
import javax.xml.namespace.QName;
import bgc.objects.vss.checkservice.v1.RequestDataCheckServiceType;
import bgc.objects.vss.checkservice.v1.ResponseDataCheckServiceType;


/**
 * This object contains factory methods for each 
 * Java content interface and Java element interface 
 * generated in the bgc.services.bealert.v1 package. 
 * <p>An ObjectFactory allows you to programatically 
 * construct new instances of the Java representation 
 * for XML content. The Java representation of XML 
 * content can consist of schema derived interfaces 
 * and classes representing the binding of schema 
 * type definitions, element declarations and model 
 * groups.  Factory methods for each of these are 
 * provided in this class.
 * 
 */
@XmlRegistry
public class ObjectFactory {

    private final static QName _RequestDataCheckService_QNAME = new QName("urn:v1.bealert.services.bgc", "RequestDataCheckService");
    private final static QName _ResponseDataCheckService_QNAME = new QName("urn:v1.bealert.services.bgc", "ResponseDataCheckService");
    private final static QName _RequestDataGetRltsData_QNAME = new QName("urn:v1.bealert.services.bgc", "RequestDataGetRltsData");
    private final static QName _ResponseDataGetRltsDataDetails_QNAME = new QName("urn:v1.bealert.services.bgc", "ResponseDataGetRltsDataDetails");
    private final static QName _RequestDataGetGisData_QNAME = new QName("urn:v1.bealert.services.bgc", "RequestDataGetGisData");
    private final static QName _ResponseDataGetGisDataDetails_QNAME = new QName("urn:v1.bealert.services.bgc", "ResponseDataGetGisDataDetails");

    /**
     * Create a new ObjectFactory that can be used to create new instances of schema derived classes for package: bgc.services.bealert.v1
     * 
     */
    public ObjectFactory() {
    }

    /**
     * Create an instance of {@link RequestDataGetRltsDataType }
     * 
     */
    public RequestDataGetRltsDataType createRequestDataGetRltsDataType() {
        return new RequestDataGetRltsDataType();
    }

    /**
     * Create an instance of {@link ResponseDataGetRltsDataType }
     * 
     */
    public ResponseDataGetRltsDataType createResponseDataGetRltsDataType() {
        return new ResponseDataGetRltsDataType();
    }

    /**
     * Create an instance of {@link RequestDataGetGisDataType }
     * 
     */
    public RequestDataGetGisDataType createRequestDataGetGisDataType() {
        return new RequestDataGetGisDataType();
    }

    /**
     * Create an instance of {@link ResponseDataGetGisDataType }
     * 
     */
    public ResponseDataGetGisDataType createResponseDataGetGisDataType() {
        return new ResponseDataGetGisDataType();
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link RequestDataCheckServiceType }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v1.bealert.services.bgc", name = "RequestDataCheckService")
    public JAXBElement<RequestDataCheckServiceType> createRequestDataCheckService(RequestDataCheckServiceType value) {
        return new JAXBElement<RequestDataCheckServiceType>(_RequestDataCheckService_QNAME, RequestDataCheckServiceType.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link ResponseDataCheckServiceType }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v1.bealert.services.bgc", name = "ResponseDataCheckService")
    public JAXBElement<ResponseDataCheckServiceType> createResponseDataCheckService(ResponseDataCheckServiceType value) {
        return new JAXBElement<ResponseDataCheckServiceType>(_ResponseDataCheckService_QNAME, ResponseDataCheckServiceType.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link RequestDataGetRltsDataType }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v1.bealert.services.bgc", name = "RequestDataGetRltsData")
    public JAXBElement<RequestDataGetRltsDataType> createRequestDataGetRltsData(RequestDataGetRltsDataType value) {
        return new JAXBElement<RequestDataGetRltsDataType>(_RequestDataGetRltsData_QNAME, RequestDataGetRltsDataType.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link ResponseDataGetRltsDataType }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v1.bealert.services.bgc", name = "ResponseDataGetRltsDataDetails")
    public JAXBElement<ResponseDataGetRltsDataType> createResponseDataGetRltsDataDetails(ResponseDataGetRltsDataType value) {
        return new JAXBElement<ResponseDataGetRltsDataType>(_ResponseDataGetRltsDataDetails_QNAME, ResponseDataGetRltsDataType.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link RequestDataGetGisDataType }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v1.bealert.services.bgc", name = "RequestDataGetGisData")
    public JAXBElement<RequestDataGetGisDataType> createRequestDataGetGisData(RequestDataGetGisDataType value) {
        return new JAXBElement<RequestDataGetGisDataType>(_RequestDataGetGisData_QNAME, RequestDataGetGisDataType.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link ResponseDataGetGisDataType }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v1.bealert.services.bgc", name = "ResponseDataGetGisDataDetails")
    public JAXBElement<ResponseDataGetGisDataType> createResponseDataGetGisDataDetails(ResponseDataGetGisDataType value) {
        return new JAXBElement<ResponseDataGetGisDataType>(_ResponseDataGetGisDataDetails_QNAME, ResponseDataGetGisDataType.class, null, value);
    }

}
