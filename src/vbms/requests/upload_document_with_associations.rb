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
        'uploadDocumentWithAssociations'
      end

      def template
        VBMS.load_erb('upload_document_xml_template.xml.erb')
      end

      def render_xml
        # TODO: this is wrong
        external_id = '123'
        filename = File.basename(@pdf_file)
        doc_type = @doc_type
        received_date = @received_at.getlocal('-05:00').strftime('%Y-%m-%d-05:00')
        source = @source
        new_mail = @new_mail
        file_number = @file_number
        subject = @exam_name
        first_name = @first_name
        middle_name = @middle_name
        last_name = @last_name

        template.result(binding)
      end

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
  end
end
