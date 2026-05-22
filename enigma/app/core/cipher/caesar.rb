# frozen_string_literal: true

#
# app/core/cipher/caesar.rb
# Responsibility: Caesar cipher (educational, ASCII 32..126 range).
#

module Enigma
  module Core
    module Cipher
      class Caesar < Base
        RANGE_SIZE = 95
        FIRST_CHAR = 32

        def algorithm_name
          "C\u00e9sar"
        end

        def key_size
          shift
        end

        private

        def validate_key!
          super
          Integer(key.to_s)
        rescue ArgumentError
          raise Errors::InvalidKeyError, "La clave debe ser un n\u00famero entero"
        end

        def shift
          Integer(key.to_s)
        end

        def encrypt_impl(plaintext)
          plaintext.bytes.map do |b|
            if b >= FIRST_CHAR && b < FIRST_CHAR + RANGE_SIZE
              (((b - FIRST_CHAR + shift) % RANGE_SIZE) + FIRST_CHAR).chr
            else
              b.chr
            end
          end.join
        end

        def decrypt_impl(ciphertext)
          ciphertext.bytes.map do |b|
            if b >= FIRST_CHAR && b < FIRST_CHAR + RANGE_SIZE
              (((b - FIRST_CHAR - shift) % RANGE_SIZE) + FIRST_CHAR).chr
            else
              b.chr
            end
          end.join
        end
      end
    end
  end
end
