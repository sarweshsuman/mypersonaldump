
package bgc.objects.vss.context.v4;

import javax.xml.bind.JAXBElement;
import javax.xml.bind.annotation.XmlElementDecl;
import javax.xml.bind.annotation.XmlRegistry;
import javax.xml.namespace.QName;


/**
 * This object contains factory methods for each 
 * Java content interface and Java element interface 
 * generated in the bgc.objects.vss.context.v4 package. 
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

    private final static QName _CorrelationId_QNAME = new QName("urn:v4.context.vss.objects.bgc", "correlationId");
    private final static QName _ConsumerApplicationId_QNAME = new QName("urn:v4.context.vss.objects.bgc", "consumerApplicationId");
    private final static QName _EndUserId_QNAME = new QName("urn:v4.context.vss.objects.bgc", "endUserId");
    private final static QName _EndUserLanguage_QNAME = new QName("urn:v4.context.vss.objects.bgc", "endUserLanguage");
    private final static QName _PropagatedKey_QNAME = new QName("urn:v4.context.vss.objects.bgc", "propagatedKey");

    /**
     * Create a new ObjectFactory that can be used to create new instances of schema derived classes for package: bgc.objects.vss.context.v4
     * 
     */
    public ObjectFactory() {
    }

    /**
     * Create an instance of {@link Context }
     * 
     */
    public Context createContext() {
        return new Context();
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link String }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v4.context.vss.objects.bgc", name = "correlationId")
    public JAXBElement<String> createCorrelationId(String value) {
        return new JAXBElement<String>(_CorrelationId_QNAME, String.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link String }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v4.context.vss.objects.bgc", name = "consumerApplicationId")
    public JAXBElement<String> createConsumerApplicationId(String value) {
        return new JAXBElement<String>(_ConsumerApplicationId_QNAME, String.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link String }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v4.context.vss.objects.bgc", name = "endUserId")
    public JAXBElement<String> createEndUserId(String value) {
        return new JAXBElement<String>(_EndUserId_QNAME, String.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link String }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v4.context.vss.objects.bgc", name = "endUserLanguage", defaultValue = "EN")
    public JAXBElement<String> createEndUserLanguage(String value) {
        return new JAXBElement<String>(_EndUserLanguage_QNAME, String.class, null, value);
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link String }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v4.context.vss.objects.bgc", name = "propagatedKey")
    public JAXBElement<String> createPropagatedKey(String value) {
        return new JAXBElement<String>(_PropagatedKey_QNAME, String.class, null, value);
    }

}
