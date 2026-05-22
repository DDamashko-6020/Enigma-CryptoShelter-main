# frozen_string_literal: true

#
# utils/file_handler.rb
# Responsibility: Binary file I/O with restrictive permissions.
#

require 'fileutils'

module Enigma
  module Utils
    class FileHandler
      FILE_MODE = 0o600

      # @param path [String] file path
      # @return [String] binary content
      def self.read(path)
        File.binread(path)
      end

      # @param path [String] file path
      # @param data [String] binary content
      def self.write(path, data)
        File.binwrite(path, data)
        File.chmod(FILE_MODE, path)
      end

      # @param path [String] file path
      # @return [Boolean]
      def self.exist?(path)
        File.exist?(path)
      end

      # @param path [String] file path
      def self.delete(path)
        FileUtils.rm_f(path)
      end
    end
  end
end
