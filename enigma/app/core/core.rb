# frozen_string_literal: true

#
# app/core/core.rb
# Responsibility: Central require orchestrator for all core modules.
# Dependency direction: errors → cipher → key_master → vault → file_lock → auth → facades
#

require_relative 'errors/cipher_error'
require_relative 'errors/vault_error'

require_relative 'cipher/base'
require_relative 'cipher/aes_gcm'
require_relative 'cipher/chacha20'
require_relative 'cipher/xor'
require_relative 'cipher/caesar'
require_relative 'cipher/factory'

require_relative 'key_master'

require_relative 'vault/null_credential'
require_relative 'vault/credential'
require_relative 'vault/storage'
require_relative 'vault/manager'

require_relative 'file_lock/locker'
require_relative 'file_lock/unlocker'

require_relative 'auth/auth_config'

require_relative 'facades/vault_facade'
require_relative 'facades/cipher_facade'
require_relative 'facades/file_lock_facade'
