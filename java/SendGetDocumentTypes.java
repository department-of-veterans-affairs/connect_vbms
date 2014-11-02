
import org.apache.ws.security.message.WSSecHeader;
import org.apache.ws.security.message.WSSecTimestamp;
import org.apache.ws.security.util.*;
import org.w3c.dom.Document;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;

public class SendGetDocumentTypes 
{
            
  public static void main(String[] args)
  {
    try 
    {
      InputStream in = new ByteArrayInputStream(Files.readAllBytes(Paths.get("getDocumentTypes.xml")));
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