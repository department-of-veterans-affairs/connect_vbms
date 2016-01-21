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
  end

  class Reference
    extend StrictlyBase64
  end
end
