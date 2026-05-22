# frozen_string_literal: true

#
# app/core/facades/vault_facade.rb
# Responsibility: Facade between UI and vault core (create/open/change_password).
#
# Pattern: Facade
#

require 'json'

module Enigma
  module Core
    module Facades
      class VaultFacade
        def self.create(master_password, security_data: nil)
          salt = KeyMaster.instance.generate_salt
          keys = KeyMaster.instance.derive_session_keys(master_password, salt)

          cipher  = Cipher::AesGcm.new(keys[:vault_key])
          storage = Vault::Storage.new(Vault::Storage::VAULT_PATH, cipher)

          if security_data
            security_data[:vault_key] = keys[:vault_key]
            storage.create_new!(salt, security_data)
          else
            storage.create_new!(salt)
          end

          manager = Vault::Manager.new(storage)
          manager.unlock
          keys.merge(manager: manager)
        end

        def self.change_password(current_keys, new_password, confirm_password,
                                 security_data: nil)
          raise Errors::VaultError, 'Las claves no coinciden' unless new_password == confirm_password
          raise Errors::InvalidKeyError, 'Mínimo 8 caracteres' if new_password.length < 8

          new_keys = Vault::Storage.reencrypt!(
            Cipher::AesGcm.new(current_keys[:vault_key]),
            new_password, security_data
          )
          build_session(new_keys)
        end

        def self.open(master_password)
          salt = Vault::Storage.read_salt(Vault::Storage::VAULT_PATH)
          keys = KeyMaster.instance.derive_session_keys(master_password, salt)
          build_session(keys)
        end

        def self.open_with_keys(keys)
          build_session(keys)
        rescue Errors::AuthTagError
          raise Errors::AuthTagError, 'Clave maestra incorrecta'
        end

        def self.build_session(keys)
          cipher  = Cipher::AesGcm.new(keys[:vault_key])
          storage = Vault::Storage.new(Vault::Storage::VAULT_PATH, cipher)
          manager = Vault::Manager.new(storage)
          manager.unlock
          keys.merge(manager: manager)
        end
      end
    end
  end
end
