
import org.apache.ws.security.message.WSSecHeader;
import org.apache.ws.security.message.WSSecTimestamp;
import org.apache.ws.security.util.*;
import org.w3c.dom.Document;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import java.io.ByteArrayInputStream;
import java.io.InputStream;

public class SendGetDocumentTypes 
{
  
  public static final String SAMPLE_SOAP_MSG =
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
          + "<SOAP-ENV:Envelope "
          +   "xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" "
          +   "xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" "
          +   "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"
          +   "<SOAP-ENV:Body>"
          +       "<add xmlns=\"http://ws.apache.org/counter/counter_port_type\">"
          +           "<value xmlns=\"\">15</value>"
          +       "</add>"
          +   "</SOAP-ENV:Body>"
          + "</SOAP-ENV:Envelope>";
          
  public static void main(String[] args)
  {
    try 
    {
      //Document doc = SOAPUtil.toSOAPPart(WSSecurityUtil.SAMPLE_SOAP_MSG);
      InputStream in = new ByteArrayInputStream(SAMPLE_SOAP_MSG.getBytes());
      DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
      factory.setNamespaceAware(true);
      DocumentBuilder builder = factory.newDocumentBuilder();
      Document doc = builder.parse(in);
      WSSecHeader secHeader = new WSSecHeader();
      secHeader.insertSecurityHeader(doc);
      WSSecTimestamp timestamp = new WSSecTimestamp();
      timestamp.setTimeToLive(300);
      Document createdDoc = timestamp.build(doc, secHeader);
      String outputString = XMLUtils.PrettyDocumentToString(createdDoc);
      System.out.println(outputString);
    }
    catch (Exception e)
    {
      System.out.println(e);
    }
  }
}