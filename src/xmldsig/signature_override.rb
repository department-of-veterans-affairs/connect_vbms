require 'xmldsig'

module Xmldsig
  class Signature
    def signature_value=(signature_value)
      signature.at_xpath("descendant::ds:SignatureValue", NAMESPACES).content =
          Base64.encode64(signature_value).chomp.gsub("\n","")
    end

    # def sign(private_key = nil, &block)
    #   binding.pry
    #   references.each { |reference| reference.sign }
    #   self.signature_value = calculate_signature_value(private_key, &block)
    # end

  end
# end


# module Xmldsig
  class SignedDocument

    # def sign(private_key = nil, instruct = true, &block)
    #   # puts private_key
    #   binding.pry
    #   signatures.reverse.each { |signature| signature.sign(private_key, &block) }
    # end

  end

  # class Reference
  #   def digest_value=(digest_value)
  #     reference.at_xpath("descendant::ds:DigestValue", NAMESPACES).content =
  #         Base64.encode64(digest_value).chomp
  #   end
  # end
end