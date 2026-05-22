# frozen_string_literal: true

RSpec.describe Enigma::Core::Vault::NullCredential do
  subject(:null) { described_class.new }

  it 'returns nil for id' do
    expect(null.id).to be_nil
  end

  it 'returns empty string for site' do
    expect(null.site).to eq('')
  end

  it 'returns empty string for username' do
    expect(null.username).to eq('')
  end

  it 'returns empty string for password' do
    expect(null.password).to eq('')
  end

  it 'returns empty string for notes' do
    expect(null.notes).to eq('')
  end

  it 'returns empty string for created_at' do
    expect(null.created_at).to eq('')
  end

  it 'returns empty string for updated_at' do
    expect(null.updated_at).to eq('')
  end

  it 'returns empty hash for to_h' do
    expect(null.to_h).to eq({})
  end

  it 'identifies as null' do
    expect(null.null?).to be true
  end

  it 'is not equal to a real Credential' do
    cred = Enigma::Core::Vault::Credential.new(site: 'S', username: 'u', password: 'p')
    expect(null).not_to eq(cred)
  end
end
