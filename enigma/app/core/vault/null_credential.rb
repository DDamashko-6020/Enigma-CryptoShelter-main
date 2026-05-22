# frozen_string_literal: true

#
# app/core/vault/null_credential.rb
# Responsibility: Null Object for Credential — safe default when none selected.
#
# Pattern: Null Object
#

module Enigma
  module Core
    module Vault
      class NullCredential
        def id
          nil
        end

        def site
          ''
        end

        def username
          ''
        end

        def password
          ''
        end

        def notes
          ''
        end

        def created_at
          ''
        end

        def updated_at
          ''
        end

        def to_h
          {}
        end

        def null?
          true
        end
      end
    end
  end
end
