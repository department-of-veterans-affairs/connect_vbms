require 'xmldsig'

module Xmldsig
  class Signature
    def signature_value=(signature_value)
      signature.at_xpath("descendant::ds:SignatureValue", NAMESPACES).content =
          Base64.strict_encode64(signature_value).chomp
    end
  end

  class Reference

    def digest_value=(digest_value)
      reference.at_xpath("descendant::ds:DigestValue", NAMESPACES).content =
          Base64.strict_encode64(digest_value).chomp
    end
  end
end
