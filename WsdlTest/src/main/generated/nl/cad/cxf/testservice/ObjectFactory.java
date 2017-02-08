
package nl.cad.cxf.testservice;

import javax.xml.bind.JAXBElement;
import javax.xml.bind.annotation.XmlElementDecl;
import javax.xml.bind.annotation.XmlRegistry;
import javax.xml.namespace.QName;


/**
 * This object contains factory methods for each 
 * Java content interface and Java element interface 
 * generated in the nl.cad.cxf.testservice package. 
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

    private final static QName _AddBirthday_QNAME = new QName("http://testservice.cxf.cad.nl/", "addBirthday");
    private final static QName _AddBirthdayResponse_QNAME = new QName("http://testservice.cxf.cad.nl/", "addBirthdayResponse");
    private final static QName _GetBirthdaysInMonth_QNAME = new QName("http://testservice.cxf.cad.nl/", "getBirthdaysInMonth");
    private final static QName _GetBirthdaysInMonthResponse_QNAME = new QName("http://testservice.cxf.cad.nl/", "getBirthdaysInMonthResponse");

    /**
     * Create a new ObjectFactory that can be used to create new instances of schema derived classes for package: nl.cad.cxf.testservice
     * 
     */
    public ObjectFactory() {
    }

    /**
     * Create an instance of {@link AddBirthday }
     * 
     */
    public AddBirthday createAddBirthday() {
        return new AddBirthday();
    }

    /**
     * Create an instance of {@link AddBirthdayResponse }
     * 
     */
    public AddBirthdayResponse createAddBirthdayResponse() {
        return new AddBirthdayResponse();
    }

    /**
     * Create an instance of {@link GetBirthdaysInMonth }
     * 
     */
    public GetBirthdaysInMonth createGetBirthdaysInMonth() {
        return new GetBirthdaysInMonth();
    }

    /**
     * Create an instance of {@link GetBirthdaysInMonthResponse }
     * 
     */
    public GetBirthdaysInMonthResponse createGetBirthdaysInMonthResponse() {
        return new GetBirthdaysInMonthResponse();
    }

    /**
     * Create an instance of {@link Birthday_Type }
     * 
     */
    public Birthday_Type createBirthday_Type() {
        return new Birthday_Type();
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link AddBirthday }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "http://testservice.cxf.cad.nl/", name = "addBirthday")
    public JAXBElement<AddBirthday> createAddBirthday(AddBirthday value) {
        return new JAXBElement<AddBirthday>(_AddBirthday_QNAME, AddBirthday.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link AddBirthdayResponse }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "http://testservice.cxf.cad.nl/", name = "addBirthdayResponse")
    public JAXBElement<AddBirthdayResponse> createAddBirthdayResponse(AddBirthdayResponse value) {
        return new JAXBElement<AddBirthdayResponse>(_AddBirthdayResponse_QNAME, AddBirthdayResponse.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link GetBirthdaysInMonth }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "http://testservice.cxf.cad.nl/", name = "getBirthdaysInMonth")
    public JAXBElement<GetBirthdaysInMonth> createGetBirthdaysInMonth(GetBirthdaysInMonth value) {
        return new JAXBElement<GetBirthdaysInMonth>(_GetBirthdaysInMonth_QNAME, GetBirthdaysInMonth.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link GetBirthdaysInMonthResponse }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "http://testservice.cxf.cad.nl/", name = "getBirthdaysInMonthResponse")
    public JAXBElement<GetBirthdaysInMonthResponse> createGetBirthdaysInMonthResponse(GetBirthdaysInMonthResponse value) {
        return new JAXBElement<GetBirthdaysInMonthResponse>(_GetBirthdaysInMonthResponse_QNAME, GetBirthdaysInMonthResponse.class, null, value);
    }

}
