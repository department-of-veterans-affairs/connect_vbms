module VBMS
  module Responses
    class Document
      attr_accessor :document_id, :filename, :doc_type, :source, :received_at, :mime_type
  
      def initialize(document_id: nil, filename: nil, doc_type: nil, source: nil, received_at: nil, mime_type: nil)
        self.document_id = document_id
        self.filename = filename
        self.doc_type = doc_type
        self.source = source
        self.received_at = received_at
        self.mime_type = mime_type
      end
  
      def self.create_from_xml(el)
        received_date = el.at_xpath('ns2:receivedDt/text()', VBMS::XML_NAMESPACES)
        
        new(document_id: el['id'],
            filename: el['filename'],
            doc_type: el['docType'],
            source: el['source'],
            mime_type: el['mimeType'],
            received_at: received_date.nil? ? nil : Time.parse(received_date.content).to_date)
      end
    end
  end
end
