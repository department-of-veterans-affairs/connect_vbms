# require 'xmldsig'
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
      doc = Nokogiri::XML::Document.parse(signature.canonicalize)
      errors = Nokogiri::XML::Schema.new(Xmldsig::XSD_FILE).validate(doc).map(&:to_s)

      # Hack to ignore InclusiveNamespaces exception
      fail Xmldsig::SchemaError.new(errors.first.message) unless errors.include? "Element '{http://www.w3.org/2001/10/xml-exc-c14n#}InclusiveNamespaces': " \
                        'No matching global element declaration available, but demanded by the ' \
                        'strict wildcard.' || !errors.any?
      # /ugly
    end

    def inclusive_namespaces
      inclusive_namespaces = signed_info.at_xpath('descendant::ds:CanonicalizationMethod/ec:InclusiveNamespaces', Xmldsig::NAMESPACES)
      if inclusive_namespaces && inclusive_namespaces.has_attribute?('PrefixList')
        inclusive_namespaces.get_attribute('PrefixList').to_s.split(' ')
      else
        []
      end
    end

    def canonicalized_signed_info
      Canonicalizer.new(signed_info, canonicalization_method, inclusive_namespaces).canonicalize
    end
  end

  class Reference
    extend StrictlyBase64
  end
end
