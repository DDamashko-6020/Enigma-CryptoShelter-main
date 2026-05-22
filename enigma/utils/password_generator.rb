# frozen_string_literal: true

#
# utils/password_generator.rb
# Responsibility: Cryptographic password generation and strength evaluation.
#

require 'securerandom'

module Enigma
  module Utils
    # Pattern: Strategy (charset)
    class PasswordGenerator
      LOWER   = ('a'..'z').to_a.freeze
      UPPER   = ('A'..'Z').to_a.freeze
      DIGITS  = ('0'..'9').to_a.freeze
      SYMBOLS = %w[! @ # $ % & * - _ = + ? .].freeze
      ALL     = (LOWER + UPPER + DIGITS + SYMBOLS).freeze

      # @param length [Integer] password length (default 20)
      # @param symbols [Boolean] include symbols (default true)
      # @return [String] generated password
      def self.generate(length: 20, symbols: true)
        charset = symbols ? ALL : (LOWER + UPPER + DIGITS)
        pass = Array.new(length) { charset[SecureRandom.random_number(charset.size)] }
        ensure_complexity!(pass, symbols)
        pass.shuffle.join
      end

      GROUP_SIZE = 4
      SEPARATOR  = '-'

      # @param password [String] raw password
      # @param group_size [Integer] characters per group
      # @param separator [String] separator between groups
      # @return [String] formatted password (e.g. "ABCD-EFGH-IJKL")
      def self.format(password, group_size: GROUP_SIZE, separator: SEPARATOR)
        raw = password.gsub(separator, '')
        raw.chars.each_slice(group_size).map(&:join).join(separator)
      end

      # @param password [String] password to evaluate
      # @return [Symbol] :weak, :medium, or :strong
      def self.strength(password)
        score = 0
        score += 1 if password.length >= 8
        score += 1 if password.length >= 16
        score += 1 if password.match?(/[A-Z]/)
        score += 1 if password.match?(/[0-9]/)
        score += 1 if password.match?(/[^A-Za-z0-9]/)

        case score
        when 0..2 then :weak
        when 3    then :medium
        else           :strong
        end
      end

      def self.ensure_complexity!(pass, symbols)
        positions = (0...pass.size).to_a.shuffle
        pos = positions.pop
        pass[pos] = UPPER[SecureRandom.random_number(UPPER.size)] unless pass.join.match?(/[A-Z]/)
        pos = positions.pop
        pass[pos] = DIGITS[SecureRandom.random_number(DIGITS.size)] unless pass.join.match?(/[0-9]/)
        return unless symbols && !pass.join.match?(/[^A-Za-z0-9]/)

        pos = positions.pop
        pass[pos] = SYMBOLS[SecureRandom.random_number(SYMBOLS.size)]
      end

      private_class_method :ensure_complexity!
    end
  end
end
