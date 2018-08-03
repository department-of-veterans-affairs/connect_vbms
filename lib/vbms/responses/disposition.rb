module VBMS
  module Responses
    class Disposition
      attr_accessor :claim_id, :contention_id, :disposition

      def initialize(claim_id: nil, contentionId: nil)
        self.claim_id = claim_id
        self.contention_id = contention_id
        self.disposition = disposition
      end

      def self.create_from_xml(el)
        new(self.claim_id = el["claimId"],
            self.contention_id = el["contentionId"],
            self.disposition = el["disposition"]
        )
      end

      def to_h
        { claim_id: claim_id, contention_id: contention_id, disposition: disposition }
      end

      alias to_s inspect
    end
  end
end
