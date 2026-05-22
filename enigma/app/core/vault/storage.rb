# frozen_string_literal: true

#
# app/core/vault/storage.rb
# Responsibility: File I/O for vault — magic, salt, security, AES-GCM payload.
# Supports v1 (old) and v2 (current with security header) formats.
#
# Pattern: Repository
#

require 'json'
require 'fileutils'
require 'digest'
require 'openssl'

module Enigma
  module Core
    module Vault
      class Storage
        VAULT_DIR  = File.expand_path('~/.enigma_cryptoshelter').freeze
        VAULT_PATH = File.join(VAULT_DIR, 'vault.dat').freeze
        DIR_MODE   = 0o700
        FILE_MODE  = 0o600

        MAGIC    = "ENIGMA\x01".b.freeze
        MAGIC_V2 = "ENIGMA\x02".b.freeze
        MAGIC_SIZE = 7

        SALT_LENGTH = 32

        NUM_QUESTIONS    = 3
        SECURITY_PER_Q   = 32
        SECURITY_SIZE    = NUM_QUESTIONS * SECURITY_PER_Q

        IV_BYTES         = 12
        TAG_BYTES        = 16
        RECOVERY_KEYSIZE = 32
        RECOVERY_SIZE    = IV_BYTES + TAG_BYTES + RECOVERY_KEYSIZE

        HEADER_SIZE_V1 = MAGIC_SIZE + SALT_LENGTH
        HEADER_SIZE_V2 = MAGIC_SIZE + SALT_LENGTH + SECURITY_SIZE + RECOVERY_SIZE

        UNUSED_INDEX = 0xFF

        SECURITY_QUESTIONS = [
          "\u00bfCu\u00e1l es el nombre de tu mascota?",
          "\u00bfCu\u00e1l es tu ciudad favorita?",
          "\u00bfCu\u00e1l es el nombre de tu primer profesor?",
          "\u00bfCu\u00e1l es tu comida favorita?",
          "\u00bfCu\u00e1l es el a\u00f1o de nacimiento de tu madre?",
          "\u00bfCu\u00e1l es tu libro favorito?",
          "\u00bfCu\u00e1l es tu pel\u00edcula favorita?",
          "\u00bfCu\u00e1l es el nombre de tu mejor amigo de la infancia?",
          "\u00bfCu\u00e1l es tu deporte favorito?",
          "\u00bfCu\u00e1l es el modelo de tu primer auto?",
          "\u00bfCu\u00e1l es el nombre de tu escuela primaria?",
          "\u00bfCu\u00e1l es tu color favorito?",
          "\u00bfCu\u00e1l es el nombre de soltera de tu madre?",
          "\u00bfCu\u00e1l es tu estaci\u00f3n del a\u00f1o favorita?",
          "\u00bfCu\u00e1l es tu artista o banda favorita?",
          "\u00bfCu\u00e1l es tu destino de viaje so\u00f1ado?",
          "\u00bfCu\u00e1l es el segundo apellido de tu padre?",
          "\u00bfCu\u00e1l es tu n\u00famero de la suerte?"
        ].freeze

        @salt_cache = nil

        def self.vault_exists?
          File.exist?(VAULT_PATH)
        end

        def self.read_salt(path = VAULT_PATH)
          return @salt_cache if @salt_cache

          raw = File.binread(path)
          raise Errors::CorruptedDataError unless raw.start_with?(MAGIC) ||
                                                  raw.start_with?(MAGIC_V2)

          @salt_cache = raw[MAGIC_SIZE, SALT_LENGTH]
        end

        def self.clear_salt_cache!
          @salt_cache = nil
        end

        def self.v2_format?(path = VAULT_PATH)
          File.binread(path).start_with?(MAGIC_V2)
        rescue StandardError
          false
        end

        def self.read_security_data(path = VAULT_PATH)
          raw = File.binread(path)
          return [] unless v2_format?(path)

          security_raw = raw[MAGIC_SIZE + SALT_LENGTH, SECURITY_SIZE]
          questions = []
          NUM_QUESTIONS.times do |i|
            offset = i * SECURITY_PER_Q
            idx = security_raw[offset].ord
            next if idx == UNUSED_INDEX

            questions << {
              question_index: idx,
              answer_hash: security_raw[offset + 1, 31]
            }
          end
          questions
        end

        def self.read_question_texts(path = VAULT_PATH)
          data = read_security_data(path)
          return try_read_questions_from_authdat if data.empty?

          data.map do |q|
            idx = q[:question_index]
            if idx.between?(0, SECURITY_QUESTIONS.length - 1)
              SECURITY_QUESTIONS[idx]
            else
              'Pregunta personalizada'
            end
          end
        end

        def self.verify_answers(entered_answers, path = VAULT_PATH)
          if v2_format?(path)
            stored = read_security_data(path)
            return false if stored.size != entered_answers.size

            stored.each_with_index.all? do |q, i|
              entered_hash = Digest::SHA256.digest(
                entered_answers[i].to_s.strip.downcase
              )[0, 31]
              constant_time_compare?(entered_hash, q[:answer_hash])
            end
          else
            try_verify_via_authdat(entered_answers)
          end
        end

        def self.read_recovery_data(_password, answers, path = VAULT_PATH)
          return try_recover_via_authdat(answers) unless v2_format?(path)

          raw = File.binread(path)
          return nil unless raw.bytesize >= HEADER_SIZE_V2

          recovery_raw = raw[MAGIC_SIZE + SALT_LENGTH + SECURITY_SIZE, RECOVERY_SIZE]
          iv  = recovery_raw[0, IV_BYTES]
          tag = recovery_raw[IV_BYTES, TAG_BYTES]
          enc = recovery_raw[IV_BYTES + TAG_BYTES, RECOVERY_KEYSIZE]
          answer_key = recovery_key_from_answers(answers)

          cipher = OpenSSL::Cipher.new('aes-256-gcm')
          cipher.decrypt
          cipher.key = answer_key
          cipher.iv = iv
          cipher.auth_tag = tag
          vault_key = cipher.update(enc) + cipher.final

          { vault_key: vault_key }
        rescue OpenSSL::Cipher::CipherError, ArgumentError, TypeError
          nil
        end

        def initialize(path, cipher)
          @path   = path
          @cipher = cipher
          @salt   = nil
          @v2     = false
        end

        def exists?
          File.exist?(@path)
        end

        def create_new!(salt, questions_and_answers = nil)
          self.class.clear_salt_cache!
          @salt = salt
          @v2   = true
          FileUtils.mkdir_p(VAULT_DIR, mode: DIR_MODE)

          if questions_and_answers
            security_data = build_security_data(questions_and_answers[:questions])
            recovery_blob = build_recovery_data(
              questions_and_answers[:vault_key],
              questions_and_answers[:answers]
            )
          else
            security_data = ([UNUSED_INDEX].pack('C') + ("\x00" * 31)) * NUM_QUESTIONS
            recovery_blob = "\x00" * RECOVERY_SIZE
          end

          payload = @cipher.encrypt(JSON.generate({ credentials: [] }))
          write_atomic(MAGIC_V2 + @salt + security_data + recovery_blob + payload)
        end

        def load
          raw = File.binread(@path)

          if raw.start_with?(MAGIC_V2)
            @v2   = true
            @salt = raw[MAGIC_SIZE, SALT_LENGTH]
            encrypted = raw[HEADER_SIZE_V2..]
          elsif raw.start_with?(MAGIC)
            @v2   = true
            @salt = raw[MAGIC_SIZE, SALT_LENGTH]
            encrypted = raw[HEADER_SIZE_V1..]

            json = @cipher.decrypt(encrypted)
            credentials = JSON.parse(json)['credentials']
                          .map { |h| Credential.from_h(h) }
            migrate_to_v2!(credentials)
            return credentials
          else
            raise Errors::CorruptedDataError
          end

          json = @cipher.decrypt(encrypted)
          JSON.parse(json)['credentials'].map { |h| Credential.from_h(h) }
        rescue OpenSSL::Cipher::CipherError => e
          raise Errors::AuthTagError, e.message
        end

        def update_security_questions!(questions, answers, vault_key)
          sec_data = build_security_data(questions)
          rec_blob = build_recovery_data(vault_key, answers)

          raw = File.binread(@path)
          new_header = raw[0, MAGIC_SIZE + SALT_LENGTH] + sec_data + rec_blob
          payload = raw[HEADER_SIZE_V2..]

          write_atomic(new_header + payload)
        end

        def migrate_to_v2!(credentials)
          security_data = ([UNUSED_INDEX].pack('C') + ("\x00" * 31)) * NUM_QUESTIONS
          recovery_blob = "\x00" * RECOVERY_SIZE
          json = JSON.generate({ credentials: credentials.map(&:to_h) })
          encrypted = @cipher.encrypt(json)
          write_atomic(MAGIC_V2 + @salt + security_data + recovery_blob + encrypted)
        end

        def save(credentials)
          json = JSON.generate({ credentials: credentials.map(&:to_h) })
          payload = @cipher.encrypt(json)

          header = build_save_header
          write_atomic(header + payload)
        end

        class << self
          def reencrypt!(current_cipher, new_password,
                         questions_and_answers = nil, path = VAULT_PATH)
            storage = new(path, current_cipher)
            credentials = storage.load

            new_salt = KeyMaster.instance.generate_salt
            new_keys = KeyMaster.instance.derive_session_keys(new_password, new_salt)
            new_cipher = Cipher::AesGcm.new(new_keys[:vault_key])

            tmp_path = "#{path}.reencrypt.tmp"

            if questions_and_answers
              qa = questions_and_answers.dup
              qa[:vault_key] = new_keys[:vault_key]
              tmp_storage = new(tmp_path, new_cipher)
              tmp_storage.create_new!(new_salt, qa)
              tmp_storage.save(credentials)
            else
              old_raw = File.binread(path)
              if old_raw.start_with?(MAGIC_V2)
                old_sec_recovery = old_raw[MAGIC_SIZE + SALT_LENGTH,
                                            SECURITY_SIZE + RECOVERY_SIZE]
                payload = new_cipher.encrypt(
                  JSON.generate({ credentials: credentials.map(&:to_h) })
                )
                tmp = "#{tmp_path}.tmp"
                FileUtils.mkdir_p(VAULT_DIR, mode: DIR_MODE)
                File.binwrite(tmp, MAGIC_V2 + new_salt + old_sec_recovery + payload)
                File.chmod(FILE_MODE, tmp)
                File.rename(tmp, tmp_path)
              else
                tmp_storage = new(tmp_path, new_cipher)
                tmp_storage.create_new!(new_salt)
                tmp_storage.save(credentials)
              end
            end

            File.rename(tmp_path, path)
            clear_salt_cache!
            new_keys
          rescue OpenSSL::Cipher::CipherError => e
            raise Errors::AuthTagError, e.message
          ensure
            tmp = "#{path}.reencrypt.tmp.tmp"
            File.delete(tmp_path) if defined?(tmp_path) && tmp_path && File.exist?(tmp_path)
            File.delete(tmp) if File.exist?(tmp)
          end
        end

        private

        def build_save_header
          raw = File.binread(@path)
          if raw.start_with?(MAGIC_V2)
            @v2 = true
            @salt = raw[MAGIC_SIZE, SALT_LENGTH]
            raw[0, HEADER_SIZE_V2]
          elsif raw.start_with?(MAGIC)
            raw[0, HEADER_SIZE_V1]
          else
            raise Errors::CorruptedDataError
          end
        end

        def write_atomic(data)
          tmp = "#{@path}.tmp"
          File.binwrite(tmp, data)
          File.chmod(FILE_MODE, tmp)
          File.rename(tmp, @path)
        ensure
          File.delete(tmp) if tmp && File.exist?(tmp)
        end

        def build_security_data(questions)
          padded = Array.new(NUM_QUESTIONS) do |i|
            if i < questions.length
              q = questions[i]
              idx = [q[:index] || q['index'] || UNUSED_INDEX].pack('C')
              hash = Digest::SHA256.digest(q[:answer].to_s.strip.downcase)[0, 31]
              idx + hash
            else
              [UNUSED_INDEX].pack('C') + ("\x00" * 31)
            end
          end
          padded.join
        end

        def build_recovery_data(vault_key, answers)
          answer_key = self.class.send(:recovery_key_from_answers, answers)

          cipher = OpenSSL::Cipher.new('aes-256-gcm')
          cipher.encrypt
          cipher.key = answer_key
          iv = cipher.random_iv
          encrypted = cipher.update(vault_key) + cipher.final
          tag = cipher.auth_tag(TAG_BYTES)

          iv + tag + encrypted
        end

        def self.recovery_key_from_answers(answers)
          OpenSSL::Digest::SHA256.digest(
            answers.map { |a| a.to_s.strip.downcase }.join
          )
        end

        def self.constant_time_compare?(left, right)
          return false unless left.bytesize == right.bytesize

          result = 0
          left.bytes.zip(right.bytes) { |x, y| result |= x ^ y }
          result.zero?
        end

        def self.try_read_questions_from_authdat
          return [] unless File.exist?(Auth::AuthConfig::AUTH_PATH)

          Auth::AuthConfig.new.load_questions_text || []
        rescue StandardError
          []
        end

        def self.try_verify_via_authdat(answers)
          return false unless File.exist?(Auth::AuthConfig::AUTH_PATH)

          Auth::AuthConfig.new.verify_answers(answers)
        rescue StandardError
          false
        end

        def self.try_recover_via_authdat(answers)
          Auth::AuthConfig.new.recover(answers)
        rescue StandardError
          nil
        end

        private_class_method :recovery_key_from_answers, :constant_time_compare?,
                             :try_read_questions_from_authdat,
                             :try_verify_via_authdat, :try_recover_via_authdat
      end
    end
  end
end
