module VBMS
  module Responses
    class Claim
      attr_accessor :claim_id
  
      def initialize(claim_id: nil)
        self.claim_id = claim_id
      end
  
      def self.create_from_xml(el)
        new(claim_id: el["id"])
      end
    end
  end
end
