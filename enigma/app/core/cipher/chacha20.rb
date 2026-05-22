# frozen_string_literal: true

#
# app/core/cipher/chacha20.rb
# Responsibility: ChaCha20-Poly1305 encryption/decryption (AEAD).
#

require 'openssl'
require 'base64'

module Enigma
  module Core
    module Cipher
      class Chacha20 < Base
        ALGORITHM = 'chacha20-poly1305'
        KEY_BYTES = 32
        NONCE_BYTES = 12
        TAG_BYTES = 16

        def algorithm_name
          'ChaCha20-Poly1305'
        end

        def key_size
          KEY_BYTES
        end

        private

        def encrypt_impl(plaintext)
          cipher = OpenSSL::Cipher.new(ALGORITHM)
          cipher.encrypt
          cipher.key = key
          nonce = cipher.random_iv
          ciphertext = cipher.update(plaintext) + cipher.final
          tag = cipher.auth_tag(TAG_BYTES)
          Base64.strict_encode64(nonce + tag + ciphertext)
        end

        def decrypt_impl(ciphertext)
          raw = Base64.strict_decode64(ciphertext)
          nonce = raw[0, NONCE_BYTES]
          tag = raw[NONCE_BYTES, TAG_BYTES]
          encrypted = raw[(NONCE_BYTES + TAG_BYTES)..]

          cipher = OpenSSL::Cipher.new(ALGORITHM)
          cipher.decrypt
          cipher.key = key
          cipher.iv = nonce
          cipher.auth_tag = tag
          cipher.update(encrypted) + cipher.final
        rescue OpenSSL::Cipher::CipherError => e
          raise Errors::AuthTagError, e.message
        rescue ArgumentError
          raise Errors::CorruptedDataError, 'Invalid base64 encoding'
        end
      end
    end
  end
end
