# frozen_string_literal: true

#
# app/core/facades/cipher_facade.rb
# Responsibility: Facade between UI and cipher core.
#
# Pattern: Facade
#

require 'digest'

module Enigma
  module Core
    module Facades
      class CipherFacade
        STRONG_ALGOS = %w[AES-256-GCM ChaCha20-Poly1305].freeze

        def self.encrypt(algorithm, key, plaintext)
          cipher = Cipher::Factory.build(algorithm, normalize_key(algorithm, key))
          cipher.encrypt(plaintext)
        end

        def self.decrypt(algorithm, key, ciphertext)
          cipher = Cipher::Factory.build(algorithm, normalize_key(algorithm, key))
          cipher.decrypt(ciphertext)
        end

        def self.normalize_key(algorithm, raw_key)
          return raw_key unless STRONG_ALGOS.include?(algorithm)

          Digest::SHA256.digest(raw_key)
        end

        def self.available_algorithms
          Cipher::Factory.available
        end
      end
    end
  end
end
