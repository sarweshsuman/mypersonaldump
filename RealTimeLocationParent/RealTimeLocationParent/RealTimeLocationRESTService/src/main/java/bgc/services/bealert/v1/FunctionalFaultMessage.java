
package bgc.services.bealert.v1;

import javax.xml.ws.WebFault;


/**
 * This class was generated by Apache CXF 3.1.6
 * 2016-07-04T14:13:14.042+02:00
 * Generated source version: 3.1.6
 */

@WebFault(name = "FunctionalError", targetNamespace = "urn:v1.functionalerror.vss.objects.bgc")
public class FunctionalFaultMessage extends Exception {
    
    private bgc.objects.vss.functionalerror.v1.FunctionalErrorType functionalError;

    public FunctionalFaultMessage() {
        super();
    }
    
    public FunctionalFaultMessage(String message) {
        super(message);
    }
    
    public FunctionalFaultMessage(String message, Throwable cause) {
        super(message, cause);
    }

    public FunctionalFaultMessage(String message, bgc.objects.vss.functionalerror.v1.FunctionalErrorType functionalError) {
        super(message);
        this.functionalError = functionalError;
    }

    public FunctionalFaultMessage(String message, bgc.objects.vss.functionalerror.v1.FunctionalErrorType functionalError, Throwable cause) {
        super(message, cause);
        this.functionalError = functionalError;
    }

    public bgc.objects.vss.functionalerror.v1.FunctionalErrorType getFaultInfo() {
        return this.functionalError;
    }
}
