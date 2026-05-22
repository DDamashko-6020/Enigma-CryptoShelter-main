# frozen_string_literal: true

#
# app/core/cipher/layered_cipher.rb
# Responsibility: Compose multiple ciphers into a single encrypt/decrypt pipeline.
#   Encrypt applies each cipher in order. Decrypt applies them in reverse.
#   Behaves exactly like any Cipher::Base — polymorphic with single ciphers.
#
# OOP pillar — POLYMORPHISM: LayeredCipher is-a Cipher::Base, usable anywhere
#   a single cipher is expected.
# OOP pillar — COMPOSITION: layers are injected, not hardcoded.
# Pattern: Composite
#

require_relative 'base'

module Enigma
  module Core
    module Cipher
      class LayeredCipher < Base
        # @param ciphers [Array<Cipher::Base>] ordered list of cipher layers
        def initialize(*ciphers)
          raise Errors::InvalidKeyError, 'At least one cipher required' if ciphers.empty?

          @ciphers = ciphers
        end

        private

        # Each inner cipher handles its own Base64 encoding, so the composite
        # passes through raw output without additional encoding.
        def encode_output(raw)
          raw
        end

        # Each inner cipher handles its own Base64 decoding, so the composite
        # passes through raw input without additional decoding.
        def decode_input(str)
          str
        end

        # Apply each cipher layer in sequence to encrypt.
        #
        # @param data [String] raw plaintext
        # @return [String] ciphertext from the last layer (already encoded)
        def encrypt_impl(data)
          @ciphers.reduce(data) { |d, cipher| cipher.encrypt(d) }
        end

        # Apply each cipher layer in reverse sequence to decrypt.
        #
        # @param raw [String] ciphertext from #encrypt (already encoded)
        # @return [String] plaintext
        def decrypt_impl(raw)
          @ciphers.reverse.reduce(raw) { |d, cipher| cipher.decrypt(d) }
        end

        public

        # @return [String] concatenated algorithm names (e.g. 'AES-256-GCM + ChaCha20-Poly1305')
        def algorithm_name
          @ciphers.map(&:algorithm_name).join(' + ')
        end

        # @return [Integer] sum of all layer key sizes
        def key_size
          @ciphers.sum(&:key_size)
        end
      end
    end
  end
end
