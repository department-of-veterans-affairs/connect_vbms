require 'open3'
require 'xmlenc'

module VBMS
  FILEDIR = File.dirname(File.absolute_path(__FILE__))
  DO_WSSE = File.join(FILEDIR, '../../src/do_wsse.sh')

  XML_NAMESPACES = {
    v4: 'http://vbms.vba.va.gov/external/eDocumentService/v4',
    doc: 'http://vbms.vba.va.gov/cdm/document/v4',
    soapenv: 'http://schemas.xmlsoap.org/soap/envelope/',
    wsse: 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
    cdm: 'http://vbms.vba.va.gov/cdm',
    xop: 'http://www.w3.org/2004/08/xop/include',
    wsse11: 'http://docs.oasis-open.org/wss/oasis-wss-wssecurity-secext-1.1.xsd',
    wsu: 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd',
    ds: 'http://www.w3.org/2000/09/xmldsig#',
    xenc: 'http://www.w3.org/2001/04/xmlenc#'
  }

  # Useful namespaces to declare at the top of a soap:Envelope
  ENVELOPE_NAMESPACE_DECLARATIONS = {
    'xmlns:soapenv' => XML_NAMESPACES[:soapenv],
    'xmlns:v4' => XML_NAMESPACES[:v4],
    'xmlns:doc' => XML_NAMESPACES[:doc],
    'xmlns:cdm' => XML_NAMESPACES[:cdm],
    'xmlns:xop' => XML_NAMESPACES[:xop]
  }

  class ClientError < StandardError
  end

  class HTTPError < ClientError
    attr_reader :code, :body

    def initialize(code, body)
      super("status_code=#{code}, body=#{body[0..250]}...")
      @code = code
      @body = body
    end
  end

  class SOAPError < ClientError
    attr_reader :body

    def initialize(msg, soap_response = nil)
      super(msg)
      @body = soap_response
    end
  end

  class EnvironmentError < ClientError
  end

  class ExecutionError < ClientError
    attr_reader :cmd, :output

    def initialize(cmd, output)
      super("Error running cmd: #{cmd}\nOutput: #{output}")
      @cmd = cmd
      @output = output
    end
  end

  private

  def self.load_erb(path)
    location = File.join(FILEDIR, '../templates', path)
    ERB.new(File.read(location))
  end

  def self.decrypt_message(infile,
                           keyfile,
                           keypass,
                           logfile,
                           ignore_timestamp = false)
    args = [DO_WSSE,
            '-i', infile,
            '-k', keyfile,
            '-p', keypass,
            '-l', logfile,
            ignore_timestamp ? '-t' : '']
    begin
      output, errors, status = Open3.capture3(*args)
    rescue TypeError
      # sometimes one of the Open3 return values is a nil and it complains about coercion
      raise ExecutionError.new(DO_WSSE + args.join(' ') + ': DecryptMessage', errors) if status != 0
    end

    fail ExecutionError.new(DO_WSSE + ' DecryptMessage', errors) if status != 0

    output
  end

  def self.decrypt_message_xml(in_xml,
                               keyfile,
                               keypass,
                               logfile,
                               ignore_timestamp = false)
    Tempfile.open('tmp') do |t|
      t.write(in_xml)
      t.flush
      return decrypt_message(t.path, keyfile, keypass, logfile,
                             ignore_timestamp: ignore_timestamp)
    end
  end

  def self.decrypt_message_xml_ruby(encrypted_xml, keyfile_p12, keypass)
    encrypted_doc = Xmlenc::EncryptedDocument.new(encrypted_xml)

    # TODO(awong): Associate a keystore class with this API instead of
    # passing path per request. The keystore client should take in a ds:KeyInfo
    # node and know how to find the associated private key.
    encryption_key = OpenSSL::PKCS12.new(File.read(keyfile_p12), keypass)
    decrypted_doc = encrypted_doc.decrypt(encryption_key.key)

    # TODO(awong): Signature verification.
    # TODO(awong): Timestamp validation.

    decrypted_doc
  end

  def self.encrypted_soap_document(infile, keyfile, keypass, request_name)
    args = [DO_WSSE,
            '-e',
            '-i', infile,
            '-k', keyfile,
            '-p', keypass,
            '-n', request_name]
    output, errors, status = Open3.capture3(*args)

    if status != 0
      fail ExecutionError.new(DO_WSSE + ' EncryptSOAPDocument', errors)
    end

    output
  end

  def self.encrypted_soap_document_xml(in_xml, keyfile, keypass, request_name)
    Tempfile.open('tmp') do |t|
      t.write(in_xml)
      t.flush
      return encrypted_soap_document(t.path, keyfile, keypass, request_name)
    end
  end
end
