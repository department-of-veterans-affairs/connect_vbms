module VBMS
  module Requests
    class AssociateRatedIssues < BaseRequest
      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v5",
        "xmlns:cdm" => "http://vbms.vba.va.gov/cdm/claim/v5",
        "xmlns:part" => "http://vbms.vba.va.gov/cdm/participant/v5"
      }.freeze

      # This all assumes that rated_issues is a hash in the form of:
      # { issue_id: contention_id, issue_id2: contention_id2 }
      def initialize(claim_id:, rated_issues:)
        @claim_id = claim_id
        @rated_issues = rated_issues
      end

      def name
        "associateRatedIssues"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:claimsv5]}"
      end

      def soap_doc
        VBMS::Requests.soap(more_namespaces: NAMESPACES) do |xml|
          @rated_issues.each do |rated_issue_id, contention_id|
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

      def handle_response(doc)
        # res = doc.at_xpath(
        #   "//associateRatedIssuesResponse:ns2:wasRatedIssueAssociated")
        puts doc
      end
    end
  end
end
