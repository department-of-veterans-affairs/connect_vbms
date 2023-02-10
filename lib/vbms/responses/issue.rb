# frozen_string_literal: true

module VBMS
    module Responses
      class Issue < OpenStruct
        def self.create(data)

          new(
            id: data[:@id],
            contention_id: data[:@contention_id],
            inferred: data[:@inferred],
            narrative: data[:@narrative],
            code: data[:@type_cd]
          )
        end
      end
    end
  end
