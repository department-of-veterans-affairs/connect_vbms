import org.apache.commons.codec.binary.Base64;
import org.apache.ws.security.components.crypto.Crypto;
import org.apache.ws.security.components.crypto.CryptoFactory;
import org.apache.ws.security.WSPasswordCallback;
import org.apache.ws.security.WSSecurityEngine;
import org.apache.ws.security.WSSecurityEngineResult;
import org.apache.ws.security.util.XMLUtils;
import org.w3c.dom.Document;
import javax.security.auth.callback.Callback;
import javax.security.auth.callback.CallbackHandler;
import javax.security.auth.callback.UnsupportedCallbackException;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import java.util.List;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.charset.Charset;
import java.nio.file.Paths;

// API docs at https://ws.apache.org/wss4j/apidocs/
public class DecryptMessage
{
  public static void main(String[] args)
  {
    try 
    {
      List<String> lines = Files.readAllLines(Paths.get(args[0]), Charset.defaultCharset());
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
    Crypto crypto = CryptoFactory.getInstance();
    CallbackHandler handler = new WSSCallbackHandler();
    WSSecurityEngine secEngine = new WSSecurityEngine();
    Document doc = getSOAPDoc(encryptedXml);
    java.util.List<WSSecurityEngineResult> results = secEngine.processSecurityHeader(doc, null, handler, crypto, crypto);
    return XMLUtils.PrettyDocumentToString(doc);
  }

  public static class WSSCallbackHandler implements CallbackHandler {
    public WSSCallbackHandler() {
    }

    public void handle(Callback[] callbacks) throws IOException, UnsupportedCallbackException {
      for (Callback callback : callbacks) {
        if (callback instanceof WSPasswordCallback) {
          System.out.println("PASSWORD CALLBACK");
          WSPasswordCallback cb = (WSPasswordCallback) callback;
          cb.setPassword("importkey");
          
          System.out.println(cb.getUsage());
          if (cb.getUsage() == WSPasswordCallback.ENCRYPTED_KEY_TOKEN) {
            System.out.println("ENCRYPTED_KEY_TOKEN");
            System.out.println(cb.getIdentifier());
            byte[] str = Base64.decodeBase64(cb.getIdentifier().getBytes());
          }
        }
      }
    }
  }
}
