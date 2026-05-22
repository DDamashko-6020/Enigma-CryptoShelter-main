# frozen_string_literal: true

#
# app/core/cipher/factory.rb
# Responsibility: Factory Method + Strategy for algorithm selection.
#
# Pattern: Factory + Strategy
#

require_relative 'aes_gcm'
require_relative 'chacha20'
require_relative 'xor'
require_relative 'caesar'

module Enigma
  module Core
    module Cipher
      class Factory
        REGISTRY = {
          'AES-256-GCM' => AesGcm,
          'ChaCha20-Poly1305' => Chacha20,
          'XOR' => Xor,
          "C\u00e9sar" => Caesar
        }.freeze

        BUILD_MAP = REGISTRY.transform_keys(&:downcase).freeze

        def self.build(algorithm, key)
          klass = REGISTRY[algorithm] || BUILD_MAP[algorithm.downcase]
          unless klass
            raise Errors::InvalidKeyError,
                  "Algoritmo desconocido: #{algorithm}"
          end

          klass.new(key)
        end

        def self.algorithms
          REGISTRY.keys
        end

        class << self
          alias available algorithms
        end
      end
    end
  end
end
