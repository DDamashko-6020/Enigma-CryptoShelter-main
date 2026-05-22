# frozen_string_literal: true

#
# app/core/file_lock/locker.rb
# Responsibility: Double-layer file encryption → .ultra format.
#

require 'fileutils'
require 'digest'

module Enigma
  module Core
    module FileLock
      class Locker
        def initialize(filelock_key, share_key)
          @layer1 = Cipher::AesGcm.new(filelock_key)
          @layer2 = Cipher::Chacha20.new(Digest::SHA256.digest(share_key))
        end

        def lock(file_path)
          content = File.binread(file_path)
          layer1  = @layer1.encrypt(content)
          layer2  = @layer2.encrypt(layer1)
          out_path = "#{file_path}.ultra"
          File.binwrite(out_path, layer2)
          out_path
        end
      end
    end
  end
end
