# frozen_string_literal: true

module VBMS
  # Current major release.
  # @return [Integer]
  MAJOR = 1

  # Current minor release.
  # @return [Integer]
  MINOR = 3

  # Current patch level.
  # @return [Integer]
  PATCH = 0

  # Full release version.
  # @return [String]
  VERSION = [MAJOR, MINOR, PATCH].join(".").freeze
end
