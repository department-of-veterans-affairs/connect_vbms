import org.apache.ws.security.message.WSSecEncrypt;
import org.apache.ws.security.message.WSSecHeader;
import org.apache.ws.security.message.WSSecSAMLToken;
import org.apache.ws.security.message.WSSecSignature;
import org.apache.ws.security.message.WSSecTimestamp;
import org.apache.ws.security.util.*;
import org.apache.ws.security.saml.*;
import org.w3c.dom.Document;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.apache.ws.security.components.crypto.*;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.nio.charset.Charset;
import org.apache.ws.security.WSEncryptionPart;
import java.util.ArrayList;
import org.apache.ws.security.SOAPConstants;
import org.apache.ws.security.WSConstants;


public class SendGetDocumentTypes 
{
            
  public static void main(String[] args)
  {
    try 
    {
      List<String> lines = Files.readAllLines(Paths.get("getDocumentTypes.xml"), Charset.defaultCharset());
      String document = "";
      for (String line : lines)
      {
        document += line;
      }
      
      document = addTimestamp(document);
      System.out.println(document);
      document = addSignature(document);
      System.out.println(document);
      document = addEncryption(document);
      //document = addSAMLToken(document);
      
      //System.out.println(document);
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
  
  public static String addTimestamp(String document) throws Exception
  {
    Document doc = getSOAPDoc(document);
    WSSecHeader secHeader = new WSSecHeader();
    secHeader.insertSecurityHeader(doc);
    WSSecTimestamp timestamp = new WSSecTimestamp();
    timestamp.setTimeToLive(300);
    Document createdDoc = timestamp.build(doc, secHeader);
    String outputString = XMLUtils.PrettyDocumentToString(createdDoc);
    return outputString;
  }
  
  public static String addSignature(String document) throws Exception
  {
    Crypto crypto = CryptoFactory.getInstance();
    WSSecSignature builder = new WSSecSignature();
    builder.setUserInfo("importkey", "importkey");
    Document doc = getSOAPDoc(document);
    SOAPConstants soapConstants = WSSecurityUtil.getSOAPConstants(doc.getDocumentElement());
    WSSecHeader secHeader = new WSSecHeader();
    secHeader.setMustUnderstand(false);
    secHeader.insertSecurityHeader(doc);
    List<WSEncryptionPart> references = new ArrayList<WSEncryptionPart>();
    references.add(new WSEncryptionPart("TS-1"));
    String soapNamespace = WSSecurityUtil.getSOAPNamespace(doc.getDocumentElement());
    WSEncryptionPart bodyPart = new WSEncryptionPart(WSConstants.ELEM_BODY, WSSecurityUtil.getSOAPNamespace(doc.getDocumentElement()), "Content");
    references.add(bodyPart);
    //builder.addReferencesToSign(references, secHeader);
    builder.setParts(references);
    Document signedDoc = builder.build(doc, crypto, secHeader);
    String outputString = XMLUtils.PrettyDocumentToString(signedDoc);
    return outputString;
  }
  
  public static String addEncryption(String document) throws Exception
  {
    Crypto crypto = CryptoFactory.getInstance();
    WSSecEncrypt builder = new WSSecEncrypt();
    builder.setUserInfo("vbms_server_key", "importkey");
    Document doc = getSOAPDoc(document);
    WSSecHeader secHeader = new WSSecHeader();
    secHeader.insertSecurityHeader(doc);
    Document encryptedDoc = builder.build(doc, crypto, secHeader);
    String outputString = XMLUtils.PrettyDocumentToString(encryptedDoc);
    return outputString;
  }
  
  /*public static String addSAMLToken(String document) throws Exception
  {
    WSSecSAMLToken wsSign = new WSSecSAMLToken();
    Document doc = getSOAPDoc(document);
    WSSecHeader secHeader = new WSSecHeader();
    secHeader.insertSecurityHeader(doc);
    Document tokenedDoc = wsSign.build(doc, samlAssertion, secHeader);
    String outputString = XMLUtils.PrettyDocumentToString(tokenedDoc);
    return outputString;    
  } 
    */   
}