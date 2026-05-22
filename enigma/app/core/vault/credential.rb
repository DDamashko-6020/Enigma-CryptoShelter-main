# frozen_string_literal: true

#
# app/core/vault/credential.rb
# Responsibility: Value Object representing a single vault credential.
#
# Pattern: Value Object
#

require 'securerandom'
require 'time'

module Enigma
  module Core
    module Vault
      class Credential
        attr_reader :id, :site, :username, :password,
                    :notes, :created_at, :updated_at

        def initialize(site:, username:, password:,
                       notes: '', id: nil,
                       created_at: nil, updated_at: nil)
          @id         = id || SecureRandom.uuid
          @site       = site.to_s.strip
          @username   = username.to_s.strip
          @password   = password.to_s
          @notes      = notes.to_s.strip
          @created_at = created_at || Time.now.iso8601
          @updated_at = updated_at || Time.now.iso8601
          validate!
          freeze
        end

        def to_h
          { id: @id, site: @site, username: @username,
            password: @password, notes: @notes,
            created_at: @created_at, updated_at: @updated_at }
        end

        def self.from_h(hash)
          h = hash.transform_keys(&:to_sym)
          new(**h)
        end

        def null?
          false
        end

        def ==(other)
          other.is_a?(Credential) && id == other.id
        end

        alias eql? ==

        def hash
          @id.hash
        end

        private

        def validate!
          raise ArgumentError, 'site vac\u00edo'     if @site.empty?
          raise ArgumentError, 'username vac\u00edo' if @username.empty?
          raise ArgumentError, 'password vac\u00edo' if @password.empty?
        end
      end
    end
  end
end
