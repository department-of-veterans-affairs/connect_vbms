module VBMS
  module Responses
    class Disposition
      attr_accessor :claim_id, :contention_id, :disposition

      def initialize(claim_id: nil, contention_id: nil, disposition: nil)
        self.claim_id = claim_id
        self.contention_id = contention_id
        self.disposition = disposition
      end

      def self.create_from_xml(el)
        new(claim_id: el["claimId"].value,
            contention_id: el["contentionId"].value,
            disposition: el["disposition"].value
           )
      end

      def to_h
        { claim_id: claim_id, contention_id: contention_id, disposition: disposition }
      end

      alias to_s inspect
    end
  end
end
