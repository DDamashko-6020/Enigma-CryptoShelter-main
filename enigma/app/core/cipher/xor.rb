# frozen_string_literal: true

#
# app/core/cipher/xor.rb
# Responsibility: XOR cipher (educational, symmetric, no auth tag).
#

require 'base64'

module Enigma
  module Core
    module Cipher
      class Xor < Base
        def algorithm_name
          'XOR'
        end

        def key_size
          key.bytesize
        end

        private

        def encrypt_impl(plaintext)
          Base64.strict_encode64(xor(plaintext))
        end

        def decrypt_impl(ciphertext)
          xor(Base64.strict_decode64(ciphertext))
        end

        def xor(data)
          key_bytes = key.bytes
          data.bytes.map.with_index { |b, i| b ^ key_bytes[i % key_bytes.size] }.pack('C*')
        end
      end
    end
  end
end
