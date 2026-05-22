# frozen_string_literal: true

RSpec.describe Enigma::Core::Cipher::Xor do
  subject(:cipher) { described_class.new('secret-key') }

  it 'round-trips plaintext' do
    plain = 'Hello XOR cipher!'
    expect(cipher.decrypt(cipher.encrypt(plain))).to eq(plain)
  end

  it 'handles binary data' do
    binary = (0..255).to_a.pack('C*')
    expect(cipher.decrypt(cipher.encrypt(binary))).to eq(binary)
  end

  it 'encrypt is symmetric (same key = same operation)' do
    e = cipher.encrypt('test')
    same = described_class.new('secret-key')
    expect(same.decrypt(e)).to eq('test')
  end

  it 'wrong key produces garbage (no auth, but still decrypts)' do
    encrypted = cipher.encrypt('test')
    wrong = described_class.new('wrong-key')
    expect(wrong.decrypt(encrypted)).not_to eq('test')
  end

  it 'raises InvalidKeyError for empty key' do
    expect { described_class.new('') }.to raise_error(Enigma::Errors::InvalidKeyError)
  end

  it 'returns algorithm_name' do
    expect(cipher.algorithm_name).to eq('XOR')
  end

  it 'returns key_size' do
    expect(cipher.key_size).to eq('secret-key'.bytesize)
  end
end
