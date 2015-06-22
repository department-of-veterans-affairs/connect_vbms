require 'nokogiri'

module SoapScum
  module XMLNamespaces
    SOAPENV = "http://schemas.xmlsoap.org/soap/envelope/"
    WSSE = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
    WSU = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
    DS = "http://www.w3.org/2000/09/xmldsig#"
  end

  class KeyStore
    CertificateAndKey = Struct.new(:certificate, :key)
    def initialize()
      @by_subject = {}
    end

    def add_pc12(path, keypass = "")
      pkcs12 = OpenSSL::PKCS12.new(File.read(path), keypass)
      entry = CertificateAndKey.new(pkcs12.certificate, pkcs12.key)

      @by_subject[x509_to_normalized_subject(pkcs12.certificate)] = entry
    end

    def get_key(keyinfo_node)
      needle = keyinfo_to_normalized_subject(keyinfo_node)
      @by_subject[needle].key
    end

    def get_certificate(keyinfo_node)
      needle = keyinfo_to_normalized_subject(keyinfo_node)
      @by_subject[needle].certificate
    end

   private
    # Takes an x509 certificate and returns an array sorted in an order that
    # allows for matching against other normalized subjects.
    def x509_to_normalized_subject(certificate)
      normalized_subject = certificate.subject.to_a.map {|name, value, _| [name, value] }.sort_by {|x| x[0] }
      normalized_subject << ['SerialNumber', certificate.serial.to_s ]
    end

    def keyinfo_to_normalized_subject(keyinfo_node)
      subject = keyinfo_node.at(
        '/ds:KeyInfo/wsse:SecurityTokenReference/ds:X509Data/ds:X509IssuerSerial/ds:X509IssuerName',
        ds: XMLNamespaces::DS,
        wsse: XMLNamespaces::WSSE)
      serial = keyinfo_node.at(
        '/ds:KeyInfo/wsse:SecurityTokenReference/ds:X509Data/ds:X509IssuerSerial/ds:X509SerialNumber',
        ds: XMLNamespaces::DS,
        wsse: XMLNamespaces::WSSE)

      normalized_subject = subject.inner_text.split(',').map {|x| x.split('=')}.sort_by{|x| x[0]}
      normalized_subject << ['SerialNumber', serial.inner_text ]
    end

    def keyinfo_has_cert?(keyinfo_node)
    end
  end
end
