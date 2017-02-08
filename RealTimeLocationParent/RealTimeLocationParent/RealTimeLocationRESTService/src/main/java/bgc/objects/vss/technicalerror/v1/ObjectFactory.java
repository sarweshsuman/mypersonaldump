
package bgc.objects.vss.technicalerror.v1;

import javax.xml.bind.JAXBElement;
import javax.xml.bind.annotation.XmlElementDecl;
import javax.xml.bind.annotation.XmlRegistry;
import javax.xml.namespace.QName;


/**
 * This object contains factory methods for each 
 * Java content interface and Java element interface 
 * generated in the bgc.objects.vss.technicalerror.v1 package. 
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

    private final static QName _TechnicalError_QNAME = new QName("urn:v1.technicalerror.vss.objects.bgc", "TechnicalError");

    /**
     * Create a new ObjectFactory that can be used to create new instances of schema derived classes for package: bgc.objects.vss.technicalerror.v1
     * 
     */
    public ObjectFactory() {
    }

    /**
     * Create an instance of {@link TechnicalErrorType }
     * 
     */
    public TechnicalErrorType createTechnicalErrorType() {
        return new TechnicalErrorType();
    }

    /**
     * Create an instance of {@link JAXBElement }{@code <}{@link TechnicalErrorType }{@code >}}
     * 
     */
    @XmlElementDecl(namespace = "urn:v1.technicalerror.vss.objects.bgc", name = "TechnicalError")
    public JAXBElement<TechnicalErrorType> createTechnicalError(TechnicalErrorType value) {
        return new JAXBElement<TechnicalErrorType>(_TechnicalError_QNAME, TechnicalErrorType.class, null, value);
    }

}
