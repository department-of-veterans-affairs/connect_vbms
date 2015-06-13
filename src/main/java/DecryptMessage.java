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

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.charset.Charset;
import java.nio.file.Paths;
import java.util.Properties;

// API docs at https://ws.apache.org/wss4j/apidocs/
public class DecryptMessage
{
  public static void main(String[] args)
  {
    if (args.length < 4) {
      throw new IllegalArgumentException("Needs 4 arguments");
    }

    try
    {
      System.setProperty("logfilename", args[2]);

      String encrypted_xml = new String(
        Files.readAllBytes(Paths.get(args[0])), Charset.defaultCharset()
      );

      String document = decrypt(encrypted_xml, args[1], args[3]);
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

  public static Crypto getSigningCrypto(String keyfile) throws Exception {
    Properties properties = new Properties();
    properties.setProperty("org.apache.ws.security.crypto.provider", "org.apache.ws.security.components.crypto.Merlin");
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.file", keyfile);
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.password", "importkey");
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.private.password", "importkey");
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.alias", "vbms_server_key");

    return CryptoFactory.getInstance(properties);
  }

  public static Crypto getDecryptionCrypto(String keyfile) throws Exception {
    Properties properties = new Properties();
    properties.setProperty("org.apache.ws.security.crypto.provider", "org.apache.ws.security.components.crypto.Merlin");
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.file", keyfile);
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.password", "importkey");
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.private.password", "importkey");

    return CryptoFactory.getInstance(properties);
  }

  public static String decrypt(String encryptedXml, String keyfile, String keypass) throws Exception {
    Crypto signCrypto = getSigningCrypto(keyfile);
    Crypto deCrypto = getDecryptionCrypto(keyfile);
    CallbackHandler handler = new WSSCallbackHandler(keypass);
    WSSecurityEngine secEngine = new WSSecurityEngine();

    Document doc = getSOAPDoc(encryptedXml);
    java.util.List<WSSecurityEngineResult> results = secEngine.processSecurityHeader(doc, null, handler, signCrypto, deCrypto);
    return XMLUtils.PrettyDocumentToString(doc);
  }

  public static class WSSCallbackHandler implements CallbackHandler {
    public String keypass;

    public WSSCallbackHandler(String keypass) {
      this.keypass = keypass;
    }

    public void handle(Callback[] callbacks) throws IOException, UnsupportedCallbackException {
      for (Callback callback : callbacks) {
        if (callback instanceof WSPasswordCallback) {
          WSPasswordCallback cb = (WSPasswordCallback) callback;
          cb.setPassword(this.keypass);
        }
      }
    }
  }
}
