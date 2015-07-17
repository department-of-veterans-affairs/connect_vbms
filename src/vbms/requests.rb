module VBMS
  module Requests
    class UploadDocumentWithAssociations
      attr_reader :file_number

      def initialize(file_number, received_at, first_name, middle_name,
                     last_name, exam_name, pdf_file, doc_type, source, new_mail)
        @file_number = file_number
        @received_at = received_at
        @first_name = first_name
        @middle_name = middle_name
        @last_name = last_name
        @exam_name = exam_name
        @pdf_file = pdf_file
        @doc_type = doc_type
        @source = source
        @new_mail = new_mail
      end

      def name
        return "uploadDocumentWithAssociations"
      end

      def template()
        return VBMS.load_erb("upload_document_xml_template.xml.erb")
      end

      def render_xml()
        # TODO: this is wrong
        externalId = "123"
        filename = File.basename(@pdf_file)
        doc_type = @doc_type
        receivedDt = @received_at.getlocal("-05:00").strftime("%Y-%m-%d-05:00")
        source = @source
        new_mail = @new_mail
        file_number = @file_number
        subject = @exam_name
        first_name = @first_name
        middle_name = @middle_name
        last_name = @last_name

        return self.template.result(binding)
      end

      def is_multipart
        return true
      end

      def multipart_file
        return @pdf_file
      end

      def handle_response(doc)
        return doc
      end
    end


    class ListDocuments
      def initialize(file_number)
        @file_number = file_number
      end

      def name
        return "listDocuments"
      end

      def template()
        return VBMS.load_erb("list_documents_xml_template.xml.erb")
      end

      def render_xml()
        file_number = @file_number

        return self.template.result(binding)
      end

      def is_multipart
        return false
      end

      def handle_response(doc)
        return doc.xpath(
          "//v4:listDocumentsResponse/v4:result", VBMS::XML_NAMESPACES
        ).map do |el|
          VBMS::Document.new(
            el["id"],
            el["filename"],
            el["docType"],
            el["source"],
            Time.parse(el.at_xpath(
              "//ns2:receivedDt/text()", VBMS::XML_NAMESPACES
            ).content).to_date,
          )
        end
      end
    end

    class FetchDocumentById
      def initialize(document_id)
        @document_id = document_id
      end

      def name
        return "fetchDocumentById"
      end

      def template()
        return VBMS.load_erb("fetch_document_by_id_xml_template.xml.erb")
      end

      def render_xml()
        document_id = @document_id

        return self.template.result(binding)
      end

      def is_multipart
        return false
      end

      def handle_response(doc)
        el = doc.at_xpath(
          "//v4:fetchDocumentResponse/v4:result", VBMS::XML_NAMESPACES
        )
        document_el = el.at_xpath(
          "//v4:document", VBMS::XML_NAMESPACES
        )
        received_date = document_el.at_xpath(
          "//ns2:receivedDt/text()", VBMS::XML_NAMESPACES
        )
        return VBMS::DocumentWithContent.new(
          VBMS::Document.new(
            document_el["id"],
            document_el["filename"],
            document_el["docType"],
            document_el["source"],
            received_date.nil? ? nil : Time.parse(received_date.content).to_date,
          ),
          Base64.decode64(el.at_xpath(
            "//v4:content/ns2:data/text()", VBMS::XML_NAMESPACES
          ).content),
        )
      end
    end

    class GetDocumentTypes
      def name
        return "getDocumentTypes"
      end

      def render_xml
        return VBMS.load_erb("get_document_types_xml_template.xml.erb").result(binding)
      end

      def is_multipart
        return false
      end

      def handle_response(doc)
        return doc.xpath("//v4:getDocumentTypesResponse/v4:result", VBMS::XML_NAMESPACES).map do |el|
          DocumentType.new(
            el["id"],
            el["description"]
          )
        end
      end
    end
  end
end
