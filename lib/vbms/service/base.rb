# frozen_string_literal: true

# abstract base class for Service classes.
# The design idea is to make it easier to wrap common tasks that involve
# multiple Request calls into a convenience class.
# One example is paged documents, where we need to iterate to find all
# the pages.

module VBMS
  module Service
    class Base
      def initialize(client:)
        @client = client
      end

      def call
        raise "Must override call method"
      end

      private

      attr_reader :client
    end
  end
end
