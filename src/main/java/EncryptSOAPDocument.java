import org.apache.ws.security.SOAPConstants;
import org.apache.ws.security.WSEncryptionPart;
import org.apache.ws.security.components.crypto.Crypto;
import org.apache.ws.security.components.crypto.CryptoFactory;
import org.apache.ws.security.message.WSSecEncrypt;
import org.apache.ws.security.message.WSSecHeader;
import org.apache.ws.security.message.WSSecSAMLToken;
import org.apache.ws.security.message.WSSecSignature;
import org.apache.ws.security.message.WSSecTimestamp;
import org.apache.ws.security.util.WSSecurityUtil;
import org.apache.ws.security.util.XMLUtils;
import org.w3c.dom.Document;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.Properties;
import java.util.ArrayList;


public class EncryptSOAPDocument
{
  private static final String VBMS_NAMESPACE = "http://vbms.vba.va.gov/external/eDocumentService/v4";
  private static final String SOAP_NAMESPACE = "http://schemas.xmlsoap.org/soap/envelope/";

  public static void main(String[] args)
  {
    System.setProperty("logfilename", "../log/upload.log");

    Properties properties = new Properties();
    properties.setProperty("org.apache.ws.security.crypto.provider", "org.apache.ws.security.components.crypto.Merlin");
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.file", args[1]);
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.password", "importkey");
    properties.setProperty("org.apache.ws.security.crypto.merlin.keystore.private.password", "importkey");

    try
    {
      String document = new String(
        Files.readAllBytes(Paths.get(args[0])), Charset.defaultCharset()
      );

      Crypto crypto = CryptoFactory.getInstance(properties);

      document = addTimestamp(document);
      document = addSignature(document, crypto, args[2]);
      document = addEncryption(document, crypto);
      System.out.println(document);
    }
    catch (Exception e)
    {
      e.printStackTrace();
      System.exit(255);
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

  public static String addTimestamp(String document) throws Exception
  {
    Document doc = getSOAPDoc(document);
    WSSecHeader secHeader = new WSSecHeader();
    secHeader.insertSecurityHeader(doc);
    WSSecTimestamp timestamp = new WSSecTimestamp();
    timestamp.setTimeToLive(300);
    Document createdDoc = timestamp.build(doc, secHeader);
    return XMLUtils.PrettyDocumentToString(createdDoc);
  }

  public static String addSignature(String document, Crypto crypto, String keypass) throws Exception
  {
    WSSecSignature builder = new WSSecSignature();
    builder.setUserInfo("importkey", keypass);
    Document doc = getSOAPDoc(document);
    SOAPConstants soapConstants = WSSecurityUtil.getSOAPConstants(doc.getDocumentElement());
    WSSecHeader secHeader = new WSSecHeader();
    secHeader.setMustUnderstand(false);
    secHeader.insertSecurityHeader(doc);

    List<WSEncryptionPart> references = new ArrayList<WSEncryptionPart>();
    references.add(new WSEncryptionPart("TS-1"));
    WSEncryptionPart body = new WSEncryptionPart("Body", SOAP_NAMESPACE, "Content");
    references.add(body);
    WSEncryptionPart documentPart = new WSEncryptionPart("document", VBMS_NAMESPACE, "Element");
    references.add(documentPart);

    builder.setParts(references);
    Document signedDoc = builder.build(doc, crypto, secHeader);
    return XMLUtils.PrettyDocumentToString(signedDoc);
  }

  public static String addEncryption(String document, Crypto crypto) throws Exception
  {
    WSSecEncrypt builder = new WSSecEncrypt();
    builder.setUserInfo("vbms_server_key", "importkey");
    Document doc = getSOAPDoc(document);
    WSSecHeader secHeader = new WSSecHeader();
    secHeader.insertSecurityHeader(doc);
    List<WSEncryptionPart> references = new ArrayList<WSEncryptionPart>();
    WSEncryptionPart documentPart = new WSEncryptionPart("document", VBMS_NAMESPACE, "Element");
    references.add(documentPart);
    WSEncryptionPart body = new WSEncryptionPart("Body", SOAP_NAMESPACE, "Content");
    references.add(body);
    builder.setParts(references);
    Document encryptedDoc = builder.build(doc, crypto, secHeader);
    return XMLUtils.PrettyDocumentToString(encryptedDoc);
  }
}
