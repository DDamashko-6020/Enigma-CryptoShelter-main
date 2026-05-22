# frozen_string_literal: true

#
# app/core/file_lock/unlocker.rb
# Responsibility: Double-layer .ultra file decryption.
#

require 'fileutils'
require 'digest'

module Enigma
  module Core
    module FileLock
      class Unlocker
        def initialize(filelock_key, share_key)
          @layer1 = Cipher::AesGcm.new(filelock_key)
          @layer2 = Cipher::Chacha20.new(Digest::SHA256.digest(share_key))
        end

        def unlock(ultra_path)
          content = File.binread(ultra_path)
          layer2  = @layer2.decrypt(content)
          layer1  = @layer1.decrypt(layer2)
          out_path = ultra_path.delete_suffix('.ultra')
          File.binwrite(out_path, layer1)
          out_path
        end
      end
    end
  end
end
