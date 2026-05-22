# frozen_string_literal: true

#
# utils/validator.rb
# Responsibility: Input validation helpers.
#

require_relative '../app/core/errors/cipher_error'

module Enigma
  module Utils
    class Validator
      # @param str [String, nil] value to check
      # @raise [Errors::InvalidKeyError] if nil or empty
      def self.not_empty(str)
        raise Enigma::Errors::InvalidKeyError, 'El valor no puede estar vac\u00edo' if str.nil? || str.to_s.strip.empty?

        str
      end
    end
  end
end
