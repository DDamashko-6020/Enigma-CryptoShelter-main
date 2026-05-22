# frozen_string_literal: true

#
# app/core/facades/cipher_facade.rb
# Responsibility: Facade between UI and cipher core.
#
# Pattern: Facade
#

module Enigma
  module Core
    module Facades
      class CipherFacade
        def self.encrypt(algorithm, key, plaintext)
          cipher = Cipher::Factory.build(algorithm, key)
          cipher.encrypt(plaintext)
        end

        def self.decrypt(algorithm, key, ciphertext)
          cipher = Cipher::Factory.build(algorithm, key)
          cipher.decrypt(ciphertext)
        end

        def self.available_algorithms
          Cipher::Factory.available
        end
      end
    end
  end
end
