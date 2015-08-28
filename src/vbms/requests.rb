module VBMS
  module Requests
    NAMESPACES = {
      "xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/",
      "xmlns:v4" => "http://vbms.vba.va.gov/external/eDocumentService/v4",
      "xmlns:doc" => "http://vbms.vba.va.gov/cdm/document/v4",
      "xmlns:cdm" => "http://vbms.vba.va.gov/cdm",
      "xmlns:xop" => "http://www.w3.org/2004/08/xop/include"
    }

    def self.soap
      Nokogiri::XML::Builder.new do |xml|
        xml['soapenv'].Envelope(VBMS::Requests::NAMESPACES) do
          xml['soapenv'].Header
          xml['soapenv'].Body { yield(xml) }
        end
      end.to_xml
    end

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
        'uploadDocumentWithAssociations'
      end

      def template
        VBMS.load_erb('upload_document_xml_template.xml.erb')
      end

      def received_date
        @received_at.getlocal("-05:00").strftime("%Y-%m-%d-05:00")
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def render_xml
        filename = File.basename(@pdf_file)

        VBMS::Requests.soap do |xml|
          xml['v4'].uploadDocumentWithAssociations do
            xml['v4'].document(
              externalId: "123",
              fileNumber: @file_number,
              filename: filename,
              docType: @doc_type,
              subject: @exam_name,
              veteranFirstName: @first_name,
              veteranMiddleName: @middle_name,
              veteranLastName: @last_name,
              newMail: @new_mail,
              source: @source
            ) do
              xml['doc'].receivedDt received_date
            end
            xml['v4'].documentContent do
              xml['doc'].data do
                xml['xop'].Include(href: filename)
              end
            end
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def multipart?
        true
      end

      def multipart_file
        @pdf_file
      end

      def handle_response(doc)
        doc
      end
    end

    class ListDocuments
      def initialize(file_number)
        @file_number = file_number
      end

      def name
        'listDocuments'
      end

      def template
        VBMS.load_erb('list_documents_xml_template.xml.erb')
      end

      def render_xml
        VBMS::Requests.soap do |xml|
          xml['v4'].listDocuments do
            xml['v4'].fileNumber @file_number
          end
        end
      end

      def multipart?
        false
      end

      def handle_response(doc)
        doc.xpath(
          '//v4:listDocumentsResponse/v4:result', VBMS::XML_NAMESPACES
        ).map do |el|
          received_date = el.at_xpath(
            'ns2:receivedDt/text()', VBMS::XML_NAMESPACES
          )
          VBMS::Document.new(
            el['id'],
            el['filename'],
            el['docType'],
            el['source'],
            received_date.nil? ? nil : Time.parse(received_date.content).to_date
          )
        end
      end
    end

    class FetchDocumentById
      def initialize(document_id)
        @document_id = document_id
      end

      def name
        'fetchDocumentById'
      end

      def template
        VBMS.load_erb('fetch_document_by_id_xml_template.xml.erb')
      end

      def render_xml
        VBMS::Requests.soap do |xml|
          xml['v4'].fetchDocumentById do
            xml['v4'].documentId @document_id
          end
        end
      end

      def multipart?
        false
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def handle_response(doc)
        el = doc.at_xpath(
          '//v4:fetchDocumentResponse/v4:result', VBMS::XML_NAMESPACES
        )
        document_el = el.at_xpath(
          '//v4:document', VBMS::XML_NAMESPACES
        )
        received_date = document_el.at_xpath(
          '//ns2:receivedDt/text()', VBMS::XML_NAMESPACES
        )
        VBMS::DocumentWithContent.new(
          VBMS::Document.new(
            document_el['id'],
            document_el['filename'],
            document_el['docType'],
            document_el['source'],
            received_date.nil? ? nil : Time.parse(received_date.content).to_date
          ),
          Base64.decode64(el.at_xpath(
            '//v4:content/ns2:data/text()', VBMS::XML_NAMESPACES
          ).content)
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end

    class GetDocumentTypes
      def name
        'getDocumentTypes'
      end

      def render_xml
        VBMS::Requests.soap do |xml|
          xml['v4'].getDocumentTypes
        end
      end

      def multipart?
        false
      end

      def handle_response(doc)
        doc.xpath(
          '//v4:getDocumentTypesResponse/v4:result', VBMS::XML_NAMESPACES
        ).map do |el|
          DocumentType.new(
            el['id'],
            el['description']
          )
        end
      end
    end
  end
end
