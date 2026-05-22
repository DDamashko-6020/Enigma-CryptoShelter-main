# frozen_string_literal: true

RSpec.describe Enigma::Core::KeyMaster do
  subject(:km) { described_class.instance }
  let(:salt) { SecureRandom.random_bytes(32) }

  describe '#derive_session_keys' do
    it 'returns vault_key as 32 bytes' do
      keys = km.derive_session_keys('password', salt)
      expect(keys[:vault_key].bytesize).to eq(32)
    end

    it 'returns filelock_key as 32 bytes' do
      keys = km.derive_session_keys('password', salt)
      expect(keys[:filelock_key].bytesize).to eq(32)
    end

    it 'vault_key differs from filelock_key' do
      keys = km.derive_session_keys('password', salt)
      expect(keys[:vault_key]).not_to eq(keys[:filelock_key])
    end

    it 'is deterministic for same password and salt' do
      k1 = km.derive_session_keys('test', salt)
      k2 = km.derive_session_keys('test', salt)
      expect(k1[:vault_key]).to eq(k2[:vault_key])
      expect(k1[:filelock_key]).to eq(k2[:filelock_key])
    end

    it 'differs for different passwords' do
      k1 = km.derive_session_keys('pass1', salt)
      k2 = km.derive_session_keys('pass2', salt)
      expect(k1[:vault_key]).not_to eq(k2[:vault_key])
      expect(k1[:filelock_key]).not_to eq(k2[:filelock_key])
    end
  end

  describe '#generate_salt' do
    it 'returns 32 bytes' do
      expect(km.generate_salt.bytesize).to eq(32)
    end

    it 'produces unique salts' do
      salts = Array.new(10) { km.generate_salt }
      expect(salts.uniq.size).to eq(10)
    end
  end
end
