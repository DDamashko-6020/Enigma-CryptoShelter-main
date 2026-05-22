# frozen_string_literal: true

RSpec.describe Enigma::Core::Vault::Credential do
  subject(:cred) { described_class.new(site: 'GitHub', username: 'user', password: 'secret', notes: 'personal') }

  describe 'initialization' do
    it 'sets attributes' do
      expect(cred.site).to eq('GitHub')
      expect(cred.username).to eq('user')
      expect(cred.password).to eq('secret')
      expect(cred.notes).to eq('personal')
    end

    it 'generates UUID as id' do
      expect(cred.id).to match(/^[0-9a-f-]{36}$/)
    end

    it 'generates ISO8601 created_at' do
      expect(cred.created_at).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'generates ISO8601 updated_at' do
      expect(cred.updated_at).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'defaults notes to empty string' do
      c = described_class.new(site: 'X', username: 'u', password: 'p')
      expect(c.notes).to eq('')
    end

    it 'uses provided id' do
      c = described_class.new(site: 'X', username: 'u', password: 'p', id: 'custom-id')
      expect(c.id).to eq('custom-id')
    end
  end

  describe 'validation' do
    it 'raises on empty site' do
      expect { described_class.new(site: '', username: 'u', password: 'p') }
        .to raise_error(ArgumentError)
    end

    it 'raises on empty username' do
      expect { described_class.new(site: 'S', username: '', password: 'p') }
        .to raise_error(ArgumentError)
    end

    it 'raises on empty password' do
      expect { described_class.new(site: 'S', username: 'u', password: '') }
        .to raise_error(ArgumentError)
    end
  end

  describe 'immutability' do
    it 'is frozen' do
      expect(cred).to be_frozen
    end
  end

  describe 'value equality' do
    it 'compares by id' do
      c1 = described_class.new(site: 'S', username: 'u', password: 'p', id: 'same-id')
      c2 = described_class.new(site: 'X', username: 'y', password: 'z', id: 'same-id')
      expect(c1).to eq(c2)
    end

    it 'distinguishes different ids' do
      c1 = described_class.new(site: 'S', username: 'u', password: 'p')
      c2 = described_class.new(site: 'S', username: 'u', password: 'p')
      expect(c1).not_to eq(c2)
    end

    it 'has null? false' do
      expect(cred.null?).to be false
    end
  end

  describe '#to_h / #from_h round-trip' do
    it 'preserves all fields' do
      restored = described_class.from_h(cred.to_h)
      expect(restored.id).to eq(cred.id)
      expect(restored.site).to eq(cred.site)
      expect(restored.username).to eq(cred.username)
      expect(restored.password).to eq(cred.password)
      expect(restored.notes).to eq(cred.notes)
      expect(restored.created_at).to eq(cred.created_at)
      expect(restored.updated_at).to eq(cred.updated_at)
    end

    it 'handles string keys' do
      hash = cred.to_h.transform_keys(&:to_s)
      restored = described_class.from_h(hash)
      expect(restored.id).to eq(cred.id)
    end
  end
end
