# frozen_string_literal: true

#
# app/core/errors/cipher_error.rb
# Responsibility: CipherError hierarchy — all cipher/encryption exceptions.
#

module Enigma
  module Errors
    class CipherError < StandardError
      def initialize(msg = 'Error de cifrado')
        super
      end
    end

    class AuthTagError < CipherError
      def initialize(msg = 'Auth tag inv\u{e1}lido \u{2014} clave incorrecta o archivo manipulado')
        super
      end
    end

    class InvalidKeyError < CipherError
      def initialize(msg = 'Clave inv\u{e1}lida')
        super
      end
    end

    class CorruptedDataError < CipherError
      def initialize(msg = 'Datos corruptos o formato inv\u{e1}lido')
        super
      end
    end
  end
end
