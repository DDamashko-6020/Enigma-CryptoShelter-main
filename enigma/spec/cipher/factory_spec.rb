# frozen_string_literal: true

RSpec.describe Enigma::Core::Cipher::Factory do
  describe '#build' do
    let(:aes_key) { "\x01" * 32 }
    let(:chacha_key) { "\x02" * 32 }

    it 'builds an AesGcm from "AES-256-GCM"' do
      cipher = described_class.build('AES-256-GCM', aes_key)
      expect(cipher).to be_a(Enigma::Core::Cipher::AesGcm)
    end

    it 'builds a ChaCha20 from "ChaCha20-Poly1305"' do
      cipher = described_class.build('ChaCha20-Poly1305', chacha_key)
      expect(cipher).to be_a(Enigma::Core::Cipher::Chacha20)
    end

    it 'builds an Xor from "XOR"' do
      cipher = described_class.build('XOR', 'mykey')
      expect(cipher).to be_a(Enigma::Core::Cipher::Xor)
    end

    it 'builds a Caesar from "César"' do
      cipher = described_class.build("C\u00e9sar", '5')
      expect(cipher).to be_a(Enigma::Core::Cipher::Caesar)
    end

    it 'is case insensitive' do
      cipher = described_class.build('aes-256-gcm', aes_key)
      expect(cipher).to be_a(Enigma::Core::Cipher::AesGcm)
    end

    it 'raises InvalidKeyError for unknown algorithm' do
      expect { described_class.build('FAKE', 'key') }
        .to raise_error(Enigma::Errors::InvalidKeyError)
    end

    it 'derives 32-byte key for AES-256-GCM' do
      cipher = described_class.build('AES-256-GCM', aes_key)
      expect(cipher.key_size).to eq(32)
    end

    it 'passes raw key for XOR' do
      cipher = described_class.build('XOR', 'mykey')
      expect(cipher.key_size).to eq(5)
    end
  end

  describe '#algorithms' do
    it 'returns all algorithm names' do
      names = described_class.algorithms
      expect(names).to include('AES-256-GCM', 'ChaCha20-Poly1305', 'XOR')
    end
  end
end
