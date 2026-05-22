# frozen_string_literal: true

#
# app/core/cipher/base.rb
# Responsibility: Abstract base class for all ciphers (Template Method).
#
# Pattern: Template Method
#

require_relative '../errors/cipher_error'

module Enigma
  module Core
    module Cipher
      class Base
        def self.new(*)
          if self == Base
            raise NotImplementedError,
                  'Cipher::Base es abstracta. Usa AesGcm, Chacha20, Xor o Caesar'
          end
          super
        end

        def initialize(key)
          @key = key
          validate_key!
        end

        def encrypt(plaintext)
          validate_input!(plaintext)
          encrypt_impl(plaintext)
        end

        def decrypt(ciphertext)
          validate_input!(ciphertext)
          decrypt_impl(ciphertext)
        end

        def algorithm_name
          raise NotImplementedError
        end

        def key_size
          raise NotImplementedError
        end

        private

        attr_reader :key

        def validate_key!
          raise Errors::InvalidKeyError if key.nil? || key.empty?
        end

        def validate_input!(data)
          raise Errors::CorruptedDataError if data.nil? || data.empty?
        end

        def encrypt_impl(_plaintext)
          raise NotImplementedError
        end

        def decrypt_impl(_ciphertext)
          raise NotImplementedError
        end
      end
    end
  end
end
