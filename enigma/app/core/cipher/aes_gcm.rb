# frozen_string_literal: true

#
# app/core/cipher/aes_gcm.rb
# Responsibility: AES-256-GCM encryption/decryption (AEAD).
#

require 'openssl'
require 'base64'

module Enigma
  module Core
    module Cipher
      class AesGcm < Base
        ALGORITHM = 'aes-256-gcm'
        KEY_BYTES = 32
        IV_BYTES  = 12
        TAG_BYTES = 16

        def algorithm_name
          'AES-256-GCM'
        end

        def key_size
          KEY_BYTES
        end

        private

        def validate_key!
          super
          raise Errors::InvalidKeyError, "Key must be #{KEY_BYTES} bytes" unless key.bytesize == KEY_BYTES
        end

        def encrypt_impl(plaintext)
          cipher = OpenSSL::Cipher.new(ALGORITHM)
          cipher.encrypt
          cipher.key = key
          iv = cipher.random_iv
          ciphertext = cipher.update(plaintext) + cipher.final
          tag = cipher.auth_tag(TAG_BYTES)
          Base64.strict_encode64(iv + tag + ciphertext)
        end

        def decrypt_impl(ciphertext)
          raw = Base64.strict_decode64(ciphertext)
          iv = raw[0, IV_BYTES]
          tag = raw[IV_BYTES, TAG_BYTES]
          encrypted = raw[(IV_BYTES + TAG_BYTES)..]

          cipher = OpenSSL::Cipher.new(ALGORITHM)
          cipher.decrypt
          cipher.key = key
          cipher.iv = iv
          cipher.auth_tag = tag
          cipher.update(encrypted) + cipher.final
        rescue OpenSSL::Cipher::CipherError => e
          raise Errors::AuthTagError, e.message
        end
      end
    end
  end
end
