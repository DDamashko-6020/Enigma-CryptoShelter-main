# frozen_string_literal: true

RSpec.describe Enigma::Utils::Validator do
  describe '.not_empty' do
    it 'passes for non-empty string' do
      expect { described_class.not_empty('valor') }.not_to raise_error
    end

    it 'raises InvalidKeyError for empty string' do
      expect { described_class.not_empty('') }
        .to raise_error(Enigma::Errors::InvalidKeyError)
    end

    it 'raises InvalidKeyError for nil' do
      expect { described_class.not_empty(nil) }
        .to raise_error(Enigma::Errors::InvalidKeyError)
    end

    it 'raises InvalidKeyError for whitespace only' do
      expect { described_class.not_empty('   ') }
        .to raise_error(Enigma::Errors::InvalidKeyError)
    end
  end
end
