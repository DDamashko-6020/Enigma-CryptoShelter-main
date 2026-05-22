# frozen_string_literal: true

#
# app/core/file_lock/locker.rb
# Responsibility: Double-layer file encryption → .ultra format binary.
# Layer 1: AES-256-GCM (filelock_key) — file read in 1MB chunks.
# Layer 2: ChaCha20-Poly1305 (share_key → SHA256).
# Output: raw binary [nonce2(12)][tag2(16)][nonce1(12)][tag1(16)][ct]
#

require 'fileutils'
require 'digest'
require 'openssl'

module Enigma
  module Core
    module FileLock
      class Locker
        CHUNK_SIZE = 1_048_576

        def initialize(filelock_key, share_key)
          @filelock_key = filelock_key
          @share_key    = Digest::SHA256.digest(share_key)
        end

        def lock(file_path)
          out_path = "#{file_path}.ultra"

          iv1, ct1, tag1 = aes_gcm_encrypt(@filelock_key, file_path)
          inner = iv1 + tag1 + ct1

          nonce2, ct2, tag2 = chacha20_encrypt(@share_key, inner)

          File.binwrite(out_path, nonce2 + tag2 + ct2)
          out_path
        rescue OpenSSL::Cipher::CipherError => e
          raise Errors::CipherError, "File lock encryption failed: #{e.message}"
        end

        private

        def aes_gcm_encrypt(key, file_path)
          cipher = OpenSSL::Cipher.new('aes-256-gcm')
          cipher.encrypt
          cipher.key = key
          iv = cipher.random_iv
          ct = String.new.b

          File.open(file_path, 'rb') do |f|
            while (chunk = f.read(CHUNK_SIZE))
              ct << cipher.update(chunk)
            end
          end

          ct << cipher.final
          tag = cipher.auth_tag(16)
          [iv, ct, tag]
        end

        def chacha20_encrypt(key, data)
          cipher = OpenSSL::Cipher.new('chacha20-poly1305')
          cipher.encrypt
          cipher.key = key
          nonce = cipher.random_iv
          ct = cipher.update(data) + cipher.final
          tag = cipher.auth_tag(16)
          [nonce, ct, tag]
        end
      end
    end
  end
end
