# frozen_string_literal: true
module SoapScum
  ##
  #  Module containing referecnes to cryptography alogrithms.
  module CryptoAlgorithms
    RSA_PKCS1_15 = 'http://www.w3.org/2001/04/xmlenc#rsa-1_5'.freeze
    RSA_OAEP = 'http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p'.freeze
    AES128 = 'http://www.w3.org/2001/04/xmlenc#aes128-cbc'.freeze
    AES256 = 'http://www.w3.org/2001/04/xmlenc#aes256-cbc'.freeze
    SHA1 = 'http://www.w3.org/2000/09/xmldsig#sha1'.freeze
    RSA_SHA1 = 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'.freeze

    # new SHA256
    SHA256 = 'http://www.w3.org/2001/04/xmlenc#sha256'.freeze
    RSA_SHA256 = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'.free

    # TODO(awong): Add triple-des support for xmlenc 1.0 compliance.
  end
end
