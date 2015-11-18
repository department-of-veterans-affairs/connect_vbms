require 'xmldsig'
require 'base64'

module StrictlyBase64
  # overrides instances of Base64::encode64 to perform strict
  # base64 encoding. this is a monkey-patch for compatibility
  # with SOAP WSSE.
  # extend with caution.

  def Base64.encode64(str)
    Base64::strict_encode64(str)
  end
end

module Xmldsig
  class Signature
    extend StrictlyBase64

#     def canonicalized_signed_info
#       info = Canonicalizer.new(signed_info, canonicalization_method).canonicalize
# puts "CANONICALIZED_SIGNED_INFO -=-=-=-=-=-=-=-=-=-=-=-=-"
# puts info

#       info
#     end
  end

  class Reference
    extend StrictlyBase64
  end

end
