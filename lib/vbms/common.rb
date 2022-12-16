# frozen_string_literal: true

# require 'xmlenc'
require "open3"

# rubocop:disable Metrics/ModuleLength
module VBMS
  FILEDIR = File.dirname(File.absolute_path(__FILE__))
  DO_WSSE = File.join(FILEDIR, "../../src/do_wsse.sh")

  if RUBY_PLATFORM == "java"
    require "java"

    PROJECT_ROOT = File.dirname(File.dirname(FILEDIR))
    ["classes", "lib/*", "lib", "src/main/properties"].each do |p|
      $CLASSPATH << File.join(PROJECT_ROOT, p)
    end

    Dir.entries(File.join(PROJECT_ROOT, "lib")).each do |p|
      require File.join(PROJECT_ROOT, "lib", p) if p.ends_with?(".jar")
    end

    java_import "EncryptSOAPDocument"
    java_import "DecryptMessage"
  end

  XML_NAMESPACES = {
    ns0: "http://vbms.vba.va.gov/cdm/claim/v4",
    upload: "http://service.efolder.vbms.vba.va.gov/eFolderUploadService",
    read: "http://service.efolder.vbms.vba.va.gov/eFolderReadService",
    v5: "http://vbms.vba.va.gov/cdm/document/v5",
    soapenv: "http://schemas.xmlsoap.org/soap/envelope/",
    wsse: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd",
    wsu: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd",
    ds: "http://www.w3.org/2000/09/xmldsig#",
    xenc: "http://www.w3.org/2001/04/xmlenc#",
    claimV4: "http://vbms.vba.va.gov/external/ClaimService/v4",
    claimV5: "http://vbms.vba.va.gov/external/ClaimService/v5"
  }.freeze

  ENDPOINTS = {
    claims: "/vbmsp2-cs/ClaimServiceV4",
    claimsv5: "/vbmsp2-cs/ClaimServiceV5",
    efolder_svc_v1: {
      read: "/vbms-efolder-svc/read-v1/eFolderReadService",
      read_inline: "/vbms-efolder-svc/read-v1/eFolderReadServiceInline",
      upload: "/vbms-efolder-svc/upload-v1/eFolderUploadService",
      association: "/vbms-efolder-svc/association-v1/eFolderAssociationService"
    }
  }.freeze

  def self.load_erb(path)
    location = File.join(FILEDIR, "../templates", path)
    ERB.new(File.read(location))
  end

  def self.decrypt_message(infile,
                           keyfile,
                           keypass,
                           logfile,
                           ignore_timestamp: false)
    args = [DO_WSSE,
            "-i", infile,
            "-k", keyfile,
            "-p", keypass,
            "-l", logfile,
            ignore_timestamp ? "-t" : ""]
    begin
      output, errors, status = Open3.capture3(*args)
    rescue TypeError
      # sometimes one of the Open3 return values is a nil and it complains about coercion
      raise ExecutionError.new("#{DO_WSSE + args.join(' ')}: DecryptMessage", errors) if status != 0
    end

    raise ExecutionError.new("#{DO_WSSE} DecryptMessage", errors) if status != 0

    output
  end

  def self.decrypt_message_xml(in_xml,
                               keyfile,
                               keypass,
                               logfile,
                               ignore_timestamp: false)
    if RUBY_PLATFORM == "java" && in_xml.length < 10.megabytes
      begin
        Java::DecryptMessage.decrypt(
          in_xml, keyfile, keypass, ignore_timestamp
        )
      rescue Java::OrgApacheWsSecurity::WSSecurityException => e
        raise ExecutionError.new("DecryptMessage.decrypt", e.backtrace)
      end
    else
      Tempfile.open("tmp") do |t|
        t.write(in_xml)
        t.flush
        return decrypt_message(t.path, keyfile, keypass, logfile,
                               ignore_timestamp: ignore_timestamp)
      end
    end
  end

  def self.decrypt_message_xml_ruby(encrypted_xml, client_key, _keypass)
    encrypted_doc = Xmlenc::EncryptedDocument.new(encrypted_xml)

    # TODO(awong): Signature verification.
    # TODO(awong): Timestamp validation.

    encrypted_doc.decrypt(client_key)
  end

  def self.encrypted_soap_document(infile, keyfile, keypass, request_name)
    args = [DO_WSSE,
            "-e",
            "-i", infile,
            "-k", keyfile,
            "-p", keypass,
            "-n", request_name]
    output, errors, status = Open3.capture3(*args)

    raise ExecutionError.new("#{DO_WSSE} EncryptSOAPDocument", errors) if status != 0

    output
  end

  def self.encrypted_soap_document_xml(in_xml, keyfile, keypass, request_name)
    return Java::EncryptSOAPDocument.encrypt(in_xml, keyfile, keypass, request_name) if RUBY_PLATFORM == "java"

    Tempfile.open("tmp") do |t|
      out = in_xml.serialize(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      t.write(out)
      t.flush
      return encrypted_soap_document(t.path, keyfile, keypass, request_name)
    end
  end
end
# rubocop:enable Metrics/ModuleLength
