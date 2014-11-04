import org.apache.ws.security.components.crypto.Crypto;
import org.apache.ws.security.components.crypto.CryptoFactory;
import org.apache.ws.security.NamePasswordCallbackHandler;
import org.apache.ws.security.WSSecurityEngine;
import org.apache.ws.security.WSSecurityEngineResult;
import org.apache.ws.security.util.XMLUtils;
import org.w3c.dom.Document;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.security.auth.callback.CallbackHandler;

import java.util.List;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.charset.Charset;
import java.nio.file.Paths;

// API docs at https://ws.apache.org/wss4j/apidocs/
public class decrypt
{
  public static void main(String[] args)
  {
    try 
    {
      List<String> lines = Files.readAllLines(Paths.get("intermediate_files/raw_response.xml"), Charset.defaultCharset());
      String encrypted_xml = "";
      for (String line : lines)
      {
        encrypted_xml += line;
      }

      String document = decrypt(encrypted_xml);

      System.out.println(document);
    }
    catch (Exception e)
    {
      e.printStackTrace();
    }
  }

  public static Document getSOAPDoc(String document) throws Exception
  {
    InputStream in = new ByteArrayInputStream(document.getBytes());
    DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
    factory.setNamespaceAware(true);
    DocumentBuilder builder = factory.newDocumentBuilder();
    Document doc = builder.parse(in);
    return doc;
  }

  public static String decrypt(String encryptedXml) throws Exception {
    CallbackHandler handler = new NamePasswordCallbackHandler("importkey", "importkey");
    WSSecurityEngine secEngine = new WSSecurityEngine();
    Crypto crypto = CryptoFactory.getInstance();

    Document doc = getSOAPDoc(encryptedXml);

    java.util.List<WSSecurityEngineResult> results = secEngine.processSecurityHeader(doc, null, handler, null, crypto);
    return XMLUtils.PrettyDocumentToString(doc);
  }
}
