# frozen_string_literal: true

RSpec.describe Enigma::Core::Cipher::Chacha20 do
  let(:key) { "\x01" * 32 }
  subject(:cipher) { described_class.new(key) }

  it 'round-trips plaintext' do
    plain = 'Hello ChaCha20-Poly1305!'
    expect(cipher.decrypt(cipher.encrypt(plain))).to eq(plain)
  end

  it 'handles binary data' do
    binary = (0..255).to_a.pack('C*')
    expect(cipher.decrypt(cipher.encrypt(binary))).to eq(binary)
  end

  it 'produces different ciphertexts due to random nonce' do
    expect(cipher.encrypt('same')).not_to eq(cipher.encrypt('same'))
  end

  it 'raises AuthTagError on wrong key' do
    encrypted = cipher.encrypt('secret')
    wrong = described_class.new("\x02" * 32)
    expect { wrong.decrypt(encrypted) }.to raise_error(Enigma::Errors::AuthTagError)
  end

  it 'raises InvalidKeyError for empty key' do
    expect { described_class.new('') }.to raise_error(Enigma::Errors::InvalidKeyError)
  end

  it 'returns correct algorithm_name' do
    expect(cipher.algorithm_name).to eq('ChaCha20-Poly1305')
  end

  it 'returns correct key_size' do
    expect(cipher.key_size).to eq(32)
  end
end
