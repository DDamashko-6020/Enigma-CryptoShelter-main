# frozen_string_literal: true

RSpec.describe Enigma::Core::Cipher::Base do
  describe 'abstract class' do
    it 'raises NotImplementedError when instantiated directly' do
      expect { described_class.new('key') }
        .to raise_error(NotImplementedError)
    end
  end

  describe 'subclass interface' do
    subject(:cipher) { Enigma::Core::Cipher::Xor.new('key') }

    it 'responds to encrypt' do
      expect(cipher).to respond_to(:encrypt)
    end

    it 'responds to decrypt' do
      expect(cipher).to respond_to(:decrypt)
    end

    it 'responds to algorithm_name' do
      expect(cipher).to respond_to(:algorithm_name)
    end

    it 'responds to key_size' do
      expect(cipher).to respond_to(:key_size)
    end
  end

  describe 'key validation in subclasses' do
    it 'raises InvalidKeyError with nil key on Xor' do
      expect { Enigma::Core::Cipher::Xor.new(nil) }
        .to raise_error(Enigma::Errors::InvalidKeyError)
    end

    it 'raises InvalidKeyError with empty key on Xor' do
      expect { Enigma::Core::Cipher::Xor.new('') }
        .to raise_error(Enigma::Errors::InvalidKeyError)
    end
  end
end
