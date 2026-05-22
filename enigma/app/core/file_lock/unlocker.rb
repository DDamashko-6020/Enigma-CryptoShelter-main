# frozen_string_literal: true

#
# app/core/file_lock/unlocker.rb
# Responsibility: Double-layer .ultra file decryption (raw binary format).
#

require 'fileutils'
require 'digest'
require 'openssl'

module Enigma
  module Core
    module FileLock
      class Unlocker
        NONCE_BYTES = 12
        TAG_BYTES   = 16

        def initialize(filelock_key, share_key)
          @filelock_key = filelock_key
          @share_key    = Digest::SHA256.digest(share_key)
        end

        def unlock(ultra_path)
          data = File.binread(ultra_path)
          inner = chacha20_decrypt(@share_key, data)

          iv1     = inner[0, NONCE_BYTES]
          tag1    = inner[NONCE_BYTES, TAG_BYTES]
          ct1     = inner[(NONCE_BYTES + TAG_BYTES)..]

          out_path = ultra_path.delete_suffix('.ultra')
          aes_gcm_decrypt_to_file(@filelock_key, iv1, tag1, ct1, out_path)
          out_path
        rescue OpenSSL::Cipher::CipherError => e
          raise Errors::AuthTagError,
                "Wrong master password or share key: #{e.message}"
        end

        private

        def chacha20_decrypt(key, data)
          raise Errors::CorruptedDataError, 'Archivo .ultra truncado' if data.bytesize < NONCE_BYTES + TAG_BYTES

          nonce = data[0, NONCE_BYTES]
          tag   = data[NONCE_BYTES, TAG_BYTES]
          ct    = data[(NONCE_BYTES + TAG_BYTES)..]

          cipher = OpenSSL::Cipher.new('chacha20-poly1305')
          cipher.decrypt
          cipher.key = key
          cipher.iv = nonce
          cipher.auth_tag = tag
          cipher.update(ct) + cipher.final
        end

        def aes_gcm_decrypt_to_file(key, iv_bytes, tag, ct_bytes, out_path)
          cipher = OpenSSL::Cipher.new('aes-256-gcm')
          cipher.decrypt
          cipher.key = key
          cipher.iv = iv_bytes
          cipher.auth_tag = tag

          File.open(out_path, 'wb') do |out|
            offset = 0
            while offset < ct_bytes.bytesize
              slice = ct_bytes.byteslice(offset, 1_048_576)
              out.write(cipher.update(slice))
              offset += slice.bytesize
            end
            out.write(cipher.final)
          end
        end
      end
    end
  end
end
