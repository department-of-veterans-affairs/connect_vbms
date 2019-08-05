# frozen_string_literal: true

module VBMS
  class ClientError < StandardError
    alias body message

    TRANSIENT_ERRORS = [
      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3894/events/331930/
      "upstream connect error or disconnect/reset before headers",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/4403/events/293678/
      "FAILED FOR UNKNOWN REASONS",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/4035/267335/
      "Could not access remote service at"
    ].freeze

    def ignorable?
      TRANSIENT_ERRORS.any? { |transient_error| message.include?(transient_error) }
    end
  end

  class HTTPError < ClientError
    attr_reader :code, :body, :request

    def initialize(code, body, request = nil)
      @code = code
      @body = body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      @request = request
      super("status_code=#{code}, body=#{@body}, request=#{request.inspect}")
    end

    KNOWN_ERRORS = {
      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/4999/events/360484/
      "Error retrieving fileNumber by provided claimId" => "FileNumberNotFoundForClaimId",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3288/
      "additional review due to an Incident Flash" => "IncidentFlash",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3405/
      "Unable to associate rated issue, rated issue does not exist" => "RatedIssueMissing",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3467/events/321797/
      "ShareException thrown in findRatingData" => "ShareExceptionFindRatingData",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3894/
      "Requested result set exceeds acceptable size." => "DocumentTooBig",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3293/
      "WssVerification Exception - Security Verification Exception" => "Security",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3965/
      "VBMS is currently unavailable due to maintenance." => "DownForMaintenance",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3274/
      "The data value of the PostalCode did not satisfy" => "BadPostalCode",

      "ClaimNotFoundException thrown in findContentions for ClaimID" => "ClaimNotFound",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3276/events/270914/
      "A PIF for this EP code already exists." => "PIFExistsForEPCode",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3288/events/271178/
      "A duplicate claim for this EP code already exists in CorpDB" => "DuplicateEP",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3467/events/276980/
      "User is not authorized." => "UserNotAuthorized",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/4999/events/332996/
      "Logon ID \\w+ Not Found" => "UnknownUser",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3467/events/294187/
      "Veteran is employed by this station." => "VeteranEmployedByStation",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3467/events/278342/
      "insertBenefitClaim: City is null" => "ClaimantAddressMissing",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/5068/events/364152/
      "ORACLE ERROR when attempting to store PTCPNT_RLNSHP between the vet and the POA" => "MultiplePoas",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/4164/events/279584/
      "The contention is connected to an issue in ratings and cannot be deleted." => "CannotDeleteContention",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3467/events/292533/
      "The ClaimDateDt value must be a valid date for a claim." => "ClaimDateInvalid",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3894/events/308951/
      "File Number does not exist within the system." => "FilenumberDoesNotExist",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/5254/events/360180/
      "FILENUMBER does not exist within the system." => "FilenumberDoesNotExist",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3696/events/315030/
      "Document not found" => "DocumentNotFound",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/4908/events/331555/
      "Missing required field: Veteran Identifier." => "MissingVeteranIdentifier",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3728/events/331292/
      "The System has encountered an unknown error" => "Unknown",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3954/events/329778/
      "Unable to parse SOAP message" => "BadSOAPMessage",

      # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3276/events/314254/
      "missing required data" => "MissingData"
    }.freeze

    def self.from_http_error(code, body, request = nil)
      new_error = nil
      KNOWN_ERRORS.each do |msg_str, error_class_name|
        next unless body =~ /#{msg_str}/

        error_class = "VBMS::#{error_class_name}".constantize

        new_error = error_class.new(code, body, request)
        break
      end
      new_error ||= new(code, body, request)
    end
  end

  class SOAPError < ClientError
    attr_reader :body

    def initialize(msg, soap_response = nil)
      super(msg)
      @body = soap_response
    end
  end

  class EnvironmentError < ClientError
  end

  class ExecutionError < ClientError
    attr_reader :cmd, :output

    def initialize(cmd, output)
      super("Error running cmd: #{cmd}\nOutput: #{output}")
      @cmd = cmd
      @output = output
    end
  end

  class BadClaim < HTTPError; end
  class BadPostalCode < HTTPError; end
  class BadSOAPMessage < HTTPError; end
  class CannotDeleteContention < HTTPError; end
  class ClaimantAddressMissing < HTTPError; end
  class ClaimDateInvalid < HTTPError; end
  class ClaimNotFound < HTTPError; end
  class DocumentTooBig < HTTPError; end
  class DocumentNotFound < HTTPError; end
  class DownForMaintenance < HTTPError; end
  class DuplicateEP < HTTPError; end
  class FilenumberDoesNotExist < HTTPError; end
  class FileNumberNotFoundForClaimId < HTTPError; end
  class IncidentFlash < HTTPError; end
  class MissingData < HTTPError; end
  class MissingVeteranIdentifier < HTTPError; end
  class MultiplePoas < HTTPError; end
  class PIFExistsForEPCode < HTTPError; end
  class RatedIssueMissing < HTTPError; end
  class Security < HTTPError; end
  class ShareExceptionFindRatingData < HTTPError; end
  class Unknown < HTTPError; end
  class UnknownUser < HTTPError; end
  class UserNotAuthorized < HTTPError; end
  class VeteranEmployedByStation < HTTPError; end
end
