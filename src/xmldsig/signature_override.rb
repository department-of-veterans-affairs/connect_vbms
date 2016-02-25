require 'xmldsig'
require 'base64'

module StrictlyBase64
  # overrides instances of Base64::encode64 to perform strict
  # base64 encoding. this is a monkey-patch for compatibility
  # with SOAP WSSE.
  # extend with caution.

  def Base64.encode64(str)
    Base64.strict_encode64(str)
  end
end

module Xmldsig
  class Signature
    extend StrictlyBase64

    def validate_schema
      xsd = File.read(File.expand_path('../../xmldsig-core-schema.xsd', __FILE__))
      doc = Nokogiri::XML::Document.parse(signature.canonicalize)
      errors = Nokogiri::XML::Schema.new(xsd).validate(doc).map(&:to_s)
      
      # Hack to ignore InclusiveNamespaces exception
      fail Xmldsig::SchemaError.new(errors.first.message) if errors.any? unless 
        errors.include? "Element '{http://www.w3.org/2001/10/xml-exc-c14n#}InclusiveNamespaces': " \
                        'No matching global element declaration available, but demanded by the ' \
                        'strict wildcard.'
      # /ugly
    end
  end

  class Reference
    extend StrictlyBase64
  end
end
