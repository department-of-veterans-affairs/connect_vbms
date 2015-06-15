module VBMS
  FILEDIR = File.dirname(File.absolute_path(__FILE__))
  CLASSPATH = [
      File.join(FILEDIR, '../../classes'),
      File.join(FILEDIR, '../../lib'),
      File.join(FILEDIR, '../../lib/*'),
      File.join(FILEDIR, '../../src/main/properties'),
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

  class JavaExecutionError < ClientError
    attr_reader :cmd, :output

    def initialize(cmd, output)
      super("Error running cmd: #{cmd}\nOutput: #{output}")
      @cmd = cmd
      @output = output
    end
  end

  DocumentType = Struct.new("DocumentType", :type_id, :description)
  Document = Struct.new("Document", :document_id, :filename, :doc_type, :source, :received_at)
  DocumentWithContent = Struct.new("DocumentWithContent", :document, :content)

  private
    def self.load_erb(path)
      location = File.join(FILEDIR, "../templates", path)
      return ERB.new(File.read(location))
    end

    def self.shell_java(args)
      cmd = "java -classpath '#{VBMS::CLASSPATH}' #{args} 2>&1"
      output = `#{cmd}`
      if $? != 0
        raise JavaExecutionError.new(cmd, output)
      end
      return output
    end
end
