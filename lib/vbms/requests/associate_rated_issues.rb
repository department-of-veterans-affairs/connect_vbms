# frozen_string_literal: true

module VBMS
  module Requests
    class AssociateRatedIssues < BaseRequest
      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v5"
      }.freeze

      # This all assumes that rated_issue_contention_map is a hash in the form of:
      # { issue_id: contention_id, issue_id2: contention_id2 }
      def initialize(claim_id:, rated_issue_contention_map:)
        @claim_id = claim_id
        @rated_issue_contention_map = rated_issue_contention_map
      end

      def name
        "associateRatedIssues"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:claimsv5]}"
      end

      def soap_doc
        VBMS::Requests.soap(more_namespaces: NAMESPACES) do |xml|
          @rated_issue_contention_map.each do |rated_issue_id, contention_id|
            xml["cla"].associateRatedIssues do
              xml["cla"].ratedIssueId rated_issue_id
              xml["cla"].contentionId contention_id
              xml["cla"].claimId @claim_id
            end
          end
        end
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(_doc)
        # At the moment, the response body only returns true. If we get here, no other errors will have been raised.
        # We just need a success status. :)
        true
      end
    end
  end
end
