# frozen_string_literal: true

require 'tempfile'
require 'securerandom'

RSpec.describe Enigma::Core::FileLock::Locker do
  let(:filelock_key) { SecureRandom.random_bytes(32) }
  let(:share_key)    { 'test_share_key_456' }

  def make_test_file(content = 'Contenido secreto')
    tmp = Tempfile.new(['test', '.txt'])
    tmp.binmode
    tmp.write(content)
    tmp.close
    tmp
  end

  it 'produces a .ultra file' do
    tmp = make_test_file
    ultra = tmp.path + '.ultra'
    described_class.new(filelock_key, share_key).lock(tmp.path)
    expect(File.exist?(ultra)).to be true
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it '.ultra content differs from original' do
    tmp = make_test_file
    ultra = tmp.path + '.ultra'
    described_class.new(filelock_key, share_key).lock(tmp.path)
    expect(File.binread(ultra)).not_to eq('Contenido secreto')
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'two locks of same file produce different output (random IV)' do
    tmp = make_test_file
    ultra = tmp.path + '.ultra'
    locker = described_class.new(filelock_key, share_key)
    locker.lock(tmp.path)
    first = File.binread(ultra)
    File.delete(ultra)
    locker.lock(tmp.path)
    second = File.binread(ultra)
    expect(first).not_to eq(second)
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'round-trips with correct keys via Unlocker' do
    tmp = make_test_file
    ultra = tmp.path + '.ultra'
    described_class.new(filelock_key, share_key).lock(tmp.path)
    Enigma::Core::FileLock::Unlocker.new(filelock_key, share_key).unlock(ultra)
    expect(File.read(tmp.path)).to eq('Contenido secreto')
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'raises AuthTagError with wrong share key' do
    tmp = make_test_file
    ultra = tmp.path + '.ultra'
    described_class.new(filelock_key, share_key).lock(tmp.path)
    expect {
      Enigma::Core::FileLock::Unlocker.new(filelock_key, 'wrong').unlock(ultra)
    }.to raise_error(Enigma::Errors::AuthTagError)
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'raises AuthTagError with wrong master key' do
    tmp = make_test_file
    ultra = tmp.path + '.ultra'
    described_class.new(filelock_key, share_key).lock(tmp.path)
    expect {
      Enigma::Core::FileLock::Unlocker.new(SecureRandom.random_bytes(32), share_key).unlock(ultra)
    }.to raise_error(Enigma::Errors::AuthTagError)
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end
end
