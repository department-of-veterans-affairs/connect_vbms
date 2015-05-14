module VBMS
  FILEDIR = File.dirname(File.absolute_path(__FILE__))
  CLASSPATH = [
      File.join(FILEDIR, '../../classes'),
      File.join(FILEDIR, '../../lib'),
      File.join(FILEDIR, '../../lib/*'),
      FILEDIR,
  ].join(':')

  XML_NAMESPACES = {
    "v4" => "http://vbms.vba.va.gov/external/eDocumentService/v4",
    "ns2" => "http://vbms.vba.va.gov/cdm/document/v4",
  }

  class ClientError < StandardError
  end

  class HTTPError < ClientError
    attr_reader :code, :body

    def initialize(code, body)
      super(code)
      @code = code
      @body = body
    end
  end

  class SOAPError < ClientError
  end

  DocumentType = Struct.new("DocumentType", :type_id, :description)
  Document = Struct.new("Document", :document_id, :filename, :doc_type, :source, :received_at)
  DocumentWithContent = Struct.new("DocumentWithContent", :document, :content)

  private
    def self.load_erb(path)
      location = File.join(FILEDIR, "../templates", path)
      return ERB.new(File.read(location))
    end

    def self.shell_java(cmd)
      output = `java -classpath '#{VBMS::CLASSPATH}' #{cmd}`
      if $? != 0
        raise "Error running: #{cmd}"
      end
      return output
    end
end
