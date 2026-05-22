# frozen_string_literal: true

RSpec.describe Enigma::Core::Cipher::AesGcm do
  let(:key) { "\x01" * 32 }
  subject(:cipher) { described_class.new(key) }

  describe '#encrypt / #decrypt round-trip' do
    it 'returns original plaintext' do
      plain = 'Hello AES-256-GCM!'
      expect(cipher.decrypt(cipher.encrypt(plain))).to eq(plain)
    end

    it 'handles binary data' do
      binary = (0..255).to_a.pack('C*')
      expect(cipher.decrypt(cipher.encrypt(binary))).to eq(binary)
    end
  end

  describe 'random IV' do
    it 'produces different ciphertexts for same plaintext' do
      plain = 'same'
      e1 = cipher.encrypt(plain)
      e2 = cipher.encrypt(plain)
      expect(e1).not_to eq(e2)
    end
  end

  describe 'wrong key' do
    it 'raises AuthTagError on decrypt' do
      encrypted = cipher.encrypt('secret')
      wrong = described_class.new("\x02" * 32)
      expect { wrong.decrypt(encrypted) }.to raise_error(Enigma::Errors::AuthTagError)
    end
  end

  describe 'invalid key' do
    it 'raises InvalidKeyError for empty key' do
      expect { described_class.new('') }.to raise_error(Enigma::Errors::InvalidKeyError)
    end

    it 'raises InvalidKeyError for nil key' do
      expect { described_class.new(nil) }.to raise_error(Enigma::Errors::InvalidKeyError)
    end

    it 'raises InvalidKeyError for wrong size key' do
      expect { described_class.new('short') }.to raise_error(Enigma::Errors::InvalidKeyError)
    end
  end

  describe '#algorithm_name' do
    it { expect(cipher.algorithm_name).to eq('AES-256-GCM') }
  end

  describe '#key_size' do
    it { expect(cipher.key_size).to eq(32) }
  end
end
