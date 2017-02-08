
package bgc.objects.vss.context.v4;

import javax.xml.bind.annotation.XmlAccessType;
import javax.xml.bind.annotation.XmlAccessorType;
import javax.xml.bind.annotation.XmlAttribute;
import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;
import javax.xml.bind.annotation.XmlType;


/**
 * <p>Java class for anonymous complex type.
 * 
 * <p>The following schema fragment specifies the expected content contained within this class.
 * 
 * <pre>
 * &lt;complexType&gt;
 *   &lt;complexContent&gt;
 *     &lt;restriction base="{http://www.w3.org/2001/XMLSchema}anyType"&gt;
 *       &lt;sequence&gt;
 *         &lt;element ref="{urn:v4.context.vss.objects.bgc}correlationId"/&gt;
 *         &lt;element ref="{urn:v4.context.vss.objects.bgc}consumerApplicationId"/&gt;
 *         &lt;element ref="{urn:v4.context.vss.objects.bgc}endUserId" minOccurs="0"/&gt;
 *         &lt;element ref="{urn:v4.context.vss.objects.bgc}endUserLanguage" minOccurs="0"/&gt;
 *         &lt;element ref="{urn:v4.context.vss.objects.bgc}propagatedKey" minOccurs="0"/&gt;
 *       &lt;/sequence&gt;
 *       &lt;attribute name="version" type="{http://www.w3.org/2001/XMLSchema}string" default="4.0" /&gt;
 *     &lt;/restriction&gt;
 *   &lt;/complexContent&gt;
 * &lt;/complexType&gt;
 * </pre>
 * 
 * 
 */
@XmlAccessorType(XmlAccessType.FIELD)
@XmlType(name = "", propOrder = {
    "correlationId",
    "consumerApplicationId",
    "endUserId",
    "endUserLanguage",
    "propagatedKey"
})
@XmlRootElement(name = "Context")
public class Context {

    @XmlElement(required = true)
    protected String correlationId;
    @XmlElement(required = true)
    protected String consumerApplicationId;
    protected String endUserId;
    @XmlElement(defaultValue = "EN")
    protected String endUserLanguage;
    protected String propagatedKey;
    @XmlAttribute(name = "version")
    protected String version;

    /**
     * Gets the value of the correlationId property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getCorrelationId() {
        return correlationId;
    }

    /**
     * Sets the value of the correlationId property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setCorrelationId(String value) {
        this.correlationId = value;
    }

    /**
     * Gets the value of the consumerApplicationId property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getConsumerApplicationId() {
        return consumerApplicationId;
    }

    /**
     * Sets the value of the consumerApplicationId property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setConsumerApplicationId(String value) {
        this.consumerApplicationId = value;
    }

    /**
     * Gets the value of the endUserId property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getEndUserId() {
        return endUserId;
    }

    /**
     * Sets the value of the endUserId property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setEndUserId(String value) {
        this.endUserId = value;
    }

    /**
     * Gets the value of the endUserLanguage property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getEndUserLanguage() {
        return endUserLanguage;
    }

    /**
     * Sets the value of the endUserLanguage property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setEndUserLanguage(String value) {
        this.endUserLanguage = value;
    }

    /**
     * Gets the value of the propagatedKey property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getPropagatedKey() {
        return propagatedKey;
    }

    /**
     * Sets the value of the propagatedKey property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setPropagatedKey(String value) {
        this.propagatedKey = value;
    }

    /**
     * Gets the value of the version property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getVersion() {
        if (version == null) {
            return "4.0";
        } else {
            return version;
        }
    }

    /**
     * Sets the value of the version property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setVersion(String value) {
        this.version = value;
    }

}
