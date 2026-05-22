# frozen_string_literal: true

#
# app/core/key_master.rb
# Responsibility: Single-pass key derivation — ONE PBKDF2 + HKDF expansion.
# master_key never stored or returned. Zeroed in memory after use.
#
# Pattern: Singleton
#

require 'openssl'
require 'securerandom'
require 'singleton'

module Enigma
  module Core
    class KeyMaster
      include Singleton

      ITERATIONS  = ENV.fetch('ENIGMA_PBKDF2_ITER', '600000').to_i
      KEY_LENGTH  = 32
      SALT_LENGTH = 32
      DIGEST      = 'SHA256'

      def derive_session_keys(password, salt)
        master_key = pbkdf2(password, salt)

        result = {
          vault_key:    hkdf(master_key, 'enigma_vault_v1'),
          filelock_key: hkdf(master_key, 'enigma_filelock_v1')
        }

        master_key.replace("\x00" * KEY_LENGTH)
        master_key = nil
        result
      end

      def generate_salt
        SecureRandom.random_bytes(SALT_LENGTH)
      end

      private

      def pbkdf2(password, salt)
        OpenSSL::PKCS5.pbkdf2_hmac(
          password, salt, ITERATIONS, KEY_LENGTH, DIGEST
        )
      end

      def hkdf(master_key, info)
        OpenSSL::HMAC.digest(DIGEST, master_key, info + "\x01")[0, KEY_LENGTH]
      end
    end
  end
end
