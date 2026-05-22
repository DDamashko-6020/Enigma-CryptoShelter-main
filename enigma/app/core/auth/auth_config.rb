# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'openssl'
require 'securerandom'
require 'base64'
require_relative '../key_master'

module Enigma
  module Core
    module Auth
      class AuthConfig
        AUTH_DIR      = File.expand_path('~/.enigma_cryptoshelter').freeze
        AUTH_FILENAME = 'auth.dat'
        AUTH_PATH     = File.join(AUTH_DIR, AUTH_FILENAME).freeze
        DIR_MODE      = 0o700
        FILE_MODE     = 0o600

        MAGIC      = "ENIGMA_AUTH\x01".b.freeze
        MAGIC_SIZE = MAGIC.bytesize
        SALT_SIZE  = 32
        HASH_SIZE  = 32

        IV_BYTES  = 12
        TAG_BYTES = 16

        def exists?
          File.exist?(AUTH_PATH)
        end

        def create!(master_password, questions, answers = nil)
          salt = SecureRandom.random_bytes(SALT_SIZE)
          km = KeyMaster.instance
          keys = km.derive_session_keys(master_password, salt)
          verify_hash = OpenSSL::Digest::SHA256.digest(keys[:vault_key])

          payload_data = { 'questions' => questions }

          if answers
            recovery_key = recovery_key_from_answers(answers)
            data_to_encrypt = keys[:vault_key] + keys[:filelock_key]
            cipher = OpenSSL::Cipher.new('aes-256-gcm')
            cipher.encrypt
            cipher.key = recovery_key
            iv = cipher.random_iv
            encrypted = cipher.update(data_to_encrypt) + cipher.final
            tag = cipher.auth_tag(TAG_BYTES)
            payload_data['recovery_data'] = Base64.strict_encode64(iv + tag + encrypted)
          end

          payload = JSON.generate(payload_data).force_encoding('ASCII-8BIT')
          FileUtils.mkdir_p(AUTH_DIR, mode: DIR_MODE)
          File.open(AUTH_PATH, 'wb', perm: FILE_MODE) { |f| f.write(MAGIC + salt + verify_hash + payload) }
        end

        def verify(master_password)
          return nil unless exists?

          raw = read_auth_file or return nil

          salt = raw[MAGIC_SIZE, SALT_SIZE]
          stored_hash = raw[MAGIC_SIZE + SALT_SIZE, HASH_SIZE]
          return nil unless stored_hash == derive_verify_hash(master_password, salt)

          { salt: salt, questions: load_questions_with_hashes }
        rescue StandardError
          nil
        end

        def load_questions_text
          questions = load_questions_with_hashes
          questions&.map { |q| q['q'] }
        end

        def load_questions_with_hashes
          raw = read_auth_file or return nil
          data = parse_auth_json(raw)
          (data['questions'] || []).map { |q| { 'q' => q['q'], 'h' => q['h'] } }
        rescue StandardError
          nil
        end

        def verify_answers(answers)
          questions = load_questions_with_hashes or return false
          return false unless questions.size == answers.size

          questions.zip(answers).all? do |q, a|
            q['h'] == OpenSSL::Digest::SHA256.hexdigest(a.strip.downcase)
          end
        rescue StandardError
          false
        end

        def reset_master_password(new_password)
          raw = File.binread(AUTH_PATH)
          return false unless raw.start_with?(MAGIC)

          json_str = raw[(MAGIC_SIZE + SALT_SIZE + HASH_SIZE)..]

          new_salt = SecureRandom.random_bytes(SALT_SIZE)
          new_hash = derive_verify_hash(new_password, new_salt)

          FileUtils.mkdir_p(AUTH_DIR, mode: DIR_MODE)
          File.open(AUTH_PATH, 'wb', perm: FILE_MODE) { |f| f.write(MAGIC + new_salt + new_hash + json_str) }
          true
        rescue StandardError
          false
        end

        def recover(answers)
          raw = read_auth_file or return nil
          data = parse_auth_json(raw)
          recovery_b64 = data['recovery_data'] or return nil
          questions = data['questions'] or return nil

          return nil unless questions.size == answers.size

          recovery_key = recovery_key_from_answers(answers)

          raw_data = Base64.strict_decode64(recovery_b64)
          iv = raw_data[0, IV_BYTES]
          tag = raw_data[IV_BYTES, TAG_BYTES]
          encrypted = raw_data[(IV_BYTES + TAG_BYTES)..]

          cipher = OpenSSL::Cipher.new('aes-256-gcm')
          cipher.decrypt
          cipher.key = recovery_key
          cipher.iv = iv
          cipher.auth_tag = tag
          decrypted = cipher.update(encrypted) + cipher.final

          {
            vault_key: decrypted[0, 32],
            filelock_key: decrypted[32, 32]
          }
        rescue OpenSSL::Cipher::CipherError, ArgumentError, TypeError
          nil
        end

        private

        def recovery_key_from_answers(answers)
          OpenSSL::Digest::SHA256.digest(
            answers.map { |a| a.strip.downcase }.join
          )
        end

        def read_auth_file
          return nil unless exists?

          raw = File.binread(AUTH_PATH)
          return nil unless raw.start_with?(MAGIC)

          raw
        end

        def parse_auth_json(raw)
          json_str = raw[(MAGIC_SIZE + SALT_SIZE + HASH_SIZE)..]
          JSON.parse(json_str)
        end

        def derive_verify_hash(password, salt)
          km = Core::KeyMaster.instance
          keys = km.derive_session_keys(password, salt)
          OpenSSL::Digest::SHA256.digest(keys[:vault_key])
        end
      end
    end
  end
end
