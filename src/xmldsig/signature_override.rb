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


    def valid?(certificate = nil, &block)
      @errors = []
      references.each { |r| r.errors = [] }
      validate_schema
      validate_digest_values
      validate_signature_value(certificate, &block)
      # binding.pry unless errors.empty?
      errors.empty?
    end

    def validate_schema
      doc = Nokogiri::XML::Document.parse(signature.canonicalize)
      errors = Nokogiri::XML::Schema.new(Xmldsig::XSD_FILE).validate(doc)

      # raise Xmldsig::SchemaError.new(errors.first.message) if errors.any?
      puts "SCHEMA ERRORS!" if errors.any?
      puts caller
      puts errors.inspect if errors.any?
      # binding.pry if errors.any?
      errors = []
      return
    end

    def validate_signature_value(certificate)
      signature_valid = if certificate
        certificate.public_key.verify(signature_method.new, signature_value, canonicalized_signed_info)
      else
        yield(signature_value, canonicalized_signed_info, signature_algorithm)
      end

      unless signature_valid
        @errors << :signature
      end
    end
  end

  class Reference
    extend StrictlyBase64

    def validate_digest_value
puts "digest value:"
puts digest_value
puts "calc digest val:"
puts calculate_digest_value
puts "referenced node:"
# puts referenced_node
puts transforms.apply(referenced_node)
      unless digest_value == calculate_digest_value
        @errors << :digest_value
      end
    end

#     def calculate_digest_value
# puts "-- calculate digest value"

#       transformed = transforms.apply(referenced_node)
# puts transformed
#       case transformed
#         when String
#           digest_method.digest transformed
#         when Nokogiri::XML::Node
#           digest_method.digest Canonicalizer.new(transformed).canonicalize
#       end
#     end
  end
end
