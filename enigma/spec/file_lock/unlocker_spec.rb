# frozen_string_literal: true

require 'tempfile'
require 'securerandom'

RSpec.describe Enigma::Core::FileLock::Unlocker do
  let(:filelock_key) { SecureRandom.random_bytes(32) }
  let(:share_key)    { 'test_share_key_456' }

  def make_test_file(content = 'Contenido secreto')
    tmp = Tempfile.new(['test', '.txt'])
    tmp.binmode
    tmp.write(content)
    tmp.close
    tmp
  end

  it 'restores original file content exactly' do
    tmp = make_test_file
    ultra = tmp.path + '.ultra'
    Enigma::Core::FileLock::Locker.new(filelock_key, share_key).lock(tmp.path)
    described_class.new(filelock_key, share_key).unlock(ultra)
    expect(File.read(tmp.path)).to eq('Contenido secreto')
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'works with binary files' do
    binary_content = SecureRandom.random_bytes(1024)
    bin_file = Tempfile.new(['test', '.bin'])
    bin_file.binmode
    bin_file.write(binary_content)
    bin_file.close
    ultra = bin_file.path + '.ultra'

    Enigma::Core::FileLock::Locker.new(filelock_key, share_key).lock(bin_file.path)
    described_class.new(filelock_key, share_key).unlock(ultra)

    restored = File.binread(bin_file.path)
    expect(restored).to eq(binary_content)

    bin_file.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'raises AuthTagError with wrong share key' do
    tmp = make_test_file('data')
    ultra = tmp.path + '.ultra'
    Enigma::Core::FileLock::Locker.new(filelock_key, share_key).lock(tmp.path)
    expect {
      described_class.new(filelock_key, 'wrong_key').unlock(ultra)
    }.to raise_error(Enigma::Errors::AuthTagError)
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'raises AuthTagError with wrong master key' do
    tmp = make_test_file('data')
    ultra = tmp.path + '.ultra'
    Enigma::Core::FileLock::Locker.new(filelock_key, share_key).lock(tmp.path)
    expect {
      described_class.new(SecureRandom.random_bytes(32), share_key).unlock(ultra)
    }.to raise_error(Enigma::Errors::AuthTagError)
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end

  it 'raises CipherError if .ultra file is truncated' do
    tmp = make_test_file('data')
    ultra = tmp.path + '.ultra'
    Enigma::Core::FileLock::Locker.new(filelock_key, share_key).lock(tmp.path)
    File.binwrite(ultra, File.binread(ultra)[0, 10])
    expect {
      described_class.new(filelock_key, share_key).unlock(ultra)
    }.to raise_error(Enigma::Errors::CipherError)
    tmp.unlink
    File.delete(ultra) if File.exist?(ultra)
  end
end
