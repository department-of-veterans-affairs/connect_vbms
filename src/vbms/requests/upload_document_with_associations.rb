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

      def received_date
        @received_at.getlocal("-05:00").strftime("%Y-%m-%d-05:00")
      end

      def render_xml_noko
        filename = File.basename(@pdf_file)

        VBMS::Requests.soap do |xml|
          xml['v4'].uploadDocumentWithAssociations {
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
            ) {
                xml['doc'].receivedDt received_date
            }
            xml['v4'].documentContent {
              xml['doc'].data {
                xml['xop'].Include(href: filename)
              }
            }
          }
        end
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
  end
end
