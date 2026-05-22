# frozen_string_literal: true

#
# app/core/vault/manager.rb
# Responsibility: State machine for vault credentials (locked/unlocked).
# CRUD operations with search index for O(n) lookups.
#
# Pattern: State
#

require_relative '../errors/vault_error'
require_relative 'storage'
require_relative 'credential'

module Enigma
  module Core
    module Vault
      class Manager
        LOCKED   = :locked
        UNLOCKED = :unlocked

        def initialize(storage)
          @storage     = storage
          @credentials = []
          @state       = LOCKED
          @dirty       = false
          @batching    = false
          @site_index  = {}
        end

        def unlock
          @credentials = @storage.load
          @state       = UNLOCKED
          rebuild_index!
        rescue Errors::AuthTagError
          @state = LOCKED
          raise
        end

        def lock
          @credentials = []
          @state       = LOCKED
          @site_index  = {}
        end

        def unlocked?
          @state == UNLOCKED
        end

        def add(site:, username:, password:, notes: '')
          require_unlocked!
          cred = Credential.new(site: site, username: username,
                                password: password, notes: notes)
          @credentials << cred
          add_to_index!(cred)
          persist!
          cred
        end

        def all
          require_unlocked!
          @credentials.dup
        end

        def find(query)
          require_unlocked!
          return @credentials.dup if query.to_s.strip.empty?

          q = query.to_s.downcase

          exact = @site_index[q]
          return exact.dup if exact

          @credentials.select do |c|
            c.site.downcase.include?(q) || c.username.downcase.include?(q)
          end
        end

        def update(id, **fields)
          require_unlocked!
          idx = find_index!(id)
          old = @credentials[idx]
          remove_from_index!(old)
          updated = Credential.new(
            id: old.id, created_at: old.created_at,
            updated_at: Time.now.iso8601,
            site: fields.fetch(:site, old.site),
            username: fields.fetch(:username, old.username),
            password: fields.fetch(:password, old.password),
            notes: fields.fetch(:notes, old.notes)
          )
          @credentials[idx] = updated
          add_to_index!(updated)
          persist!
          updated
        end

        def delete(id)
          require_unlocked!
          idx = find_index!(id)
          removed = @credentials[idx]
          remove_from_index!(removed)
          @credentials.reject! { |c| c.id == id }
          persist!
        end

        def count
          @credentials.size
        end

        def batch
          @batching = true
          yield
        ensure
          @batching = false
          persist! if @dirty
          @dirty = false
        end

        private

        def require_unlocked!
          raise Errors::VaultLockedError unless unlocked?
        end

        def find_index!(id)
          idx = @credentials.index { |c| c.id == id }
          raise Errors::CredentialNotFoundError, id if idx.nil?

          idx
        end

        def persist!
          if @batching
            @dirty = true
          else
            @storage.save(@credentials)
          end
        end

        def rebuild_index!
          @site_index = @credentials.each_with_object({}) do |c, idx|
            key = c.site.downcase
            idx[key] ||= []
            idx[key] << c
          end
        end

        def add_to_index!(credential)
          key = credential.site.downcase
          @site_index[key] ||= []
          @site_index[key] << credential
        end

        def remove_from_index!(credential)
          key = credential.site.downcase
          @site_index[key]&.reject! { |c| c.id == credential.id }
        end
      end
    end
  end
end
