# frozen_string_literal: true

RSpec.describe Enigma::Core::Vault::Storage do
  subject(:storage) { described_class.new(tmp_path, cipher) }

  let(:tmp_path) { File.join('/tmp', "enigma_vault_test_#{Time.now.to_i}_#{rand(9999)}.vault") }
  let(:password) { 'test-password' }
  let(:salt) { SecureRandom.random_bytes(32) }
  let(:vault_key) { Enigma::Core::KeyMaster.instance.derive_session_keys(password, salt)[:vault_key] }
  let(:cipher) { Enigma::Core::Cipher::AesGcm.new(vault_key) }

  before do
    FileUtils.rm_f(tmp_path)
    described_class.clear_salt_cache!
  end
  after(:each) { FileUtils.rm_f(tmp_path) if File.exist?(tmp_path) }

  describe '#exists?' do
    it 'returns false when file missing' do
      expect(storage.exists?).to be false
    end

    it 'returns true after create_new!' do
      storage.create_new!(salt)
      expect(storage.exists?).to be true
    end
  end

  describe '#create_new!' do
    it 'creates an empty vault file' do
      storage.create_new!(salt)
      expect(File.exist?(tmp_path)).to be true
    end

    it 'sets restrictive permissions' do
      storage.create_new!(salt)
      mode = File.stat(tmp_path).mode & 0o777
      expect(mode).to eq(0o600)
    end

    it 'writes a full header (magic + salt + security + recovery)' do
      storage.create_new!(salt)
      raw = File.binread(tmp_path)
      header_size = described_class::MAGIC_SIZE + described_class::SALT_LENGTH +
                    described_class::SECURITY_SIZE + described_class::RECOVERY_SIZE
      expect(raw.bytesize).to be > header_size
      expect(raw).to start_with(described_class::MAGIC_V2)
    end
  end

  describe '#load' do
    it 'returns empty array for new vault' do
      storage.create_new!(salt)
      expect(storage.load).to eq([])
    end

    it 'raises CorruptedDataError for invalid file format' do
      File.binwrite(tmp_path, "\x00\x00\x00")
      expect { storage.load }.to raise_error(Enigma::Errors::CorruptedDataError)
    end
  end

  describe '#save / #load round-trip' do
    it 'persists and retrieves credentials' do
      storage.create_new!(salt)
      cred = Enigma::Core::Vault::Credential.new(site: 'S', username: 'u', password: 'p')
      storage.save([cred])
      loaded = storage.load
      expect(loaded.size).to eq(1)
      expect(loaded.first.site).to eq('S')
    end

    it 'overwrites existing data' do
      storage.create_new!(salt)
      c1 = Enigma::Core::Vault::Credential.new(site: 'A', username: 'u', password: 'p')
      c2 = Enigma::Core::Vault::Credential.new(site: 'B', username: 'v', password: 'q')
      storage.save([c1])
      storage.save([c2])
      expect(storage.load.size).to eq(1)
    end
  end

  describe '.vault_exists?' do
    it 'returns false when vault file missing' do
      stub_const("#{described_class}::VAULT_PATH", tmp_path)
      expect(described_class.vault_exists?).to be false
    end

    it 'returns true after vault creation' do
      stub_const("#{described_class}::VAULT_PATH", tmp_path)
      storage.create_new!(salt)
      expect(described_class.vault_exists?).to be true
    end
  end

  describe '.read_salt' do
    it 'reads salt from vault file' do
      storage.create_new!(salt)
      read = described_class.read_salt(tmp_path)
      expect(read).to eq(salt)
    end

    it 'raises CorruptedDataError for short file' do
      File.binwrite(tmp_path, 'x')
      expect { described_class.read_salt(tmp_path) }
        .to raise_error(Enigma::Errors::CorruptedDataError)
    end
  end

  describe '.read_security_data' do
    it 'reads security questions from header' do
      questions = [
        { index: 0, answer: 'fluffy' },
        { index: 5, answer: 'moby' }
      ]
      answers = %w[fluffy moby]
      storage.create_new!(salt, {
        questions: questions,
        answers: answers,
        vault_key: vault_key
      })
      data = described_class.read_security_data(tmp_path)
      expect(data.size).to eq(2)
      expect(data[0][:question_index]).to eq(0)
      expect(data[1][:question_index]).to eq(5)
    end
  end

  describe '.verify_answers' do
    it 'verifies correct answers' do
      questions = [
        { index: 0, answer: 'Fluffy' },
        { index: 5, answer: 'Moby' }
      ]
      answers = %w[Fluffy Moby]
      storage.create_new!(salt, {
        questions: questions,
        answers: answers,
        vault_key: vault_key
      })
      expect(described_class.verify_answers(%w[Fluffy Moby], tmp_path)).to be true
    end

    it 'rejects wrong answers' do
      questions = [
        { index: 0, answer: 'fluffy' },
        { index: 5, answer: 'moby' }
      ]
      answers = %w[fluffy moby]
      storage.create_new!(salt, {
        questions: questions,
        answers: answers,
        vault_key: vault_key
      })
      expect(described_class.verify_answers(%w[wrong wrong], tmp_path)).to be false
    end
  end

  describe '.reencrypt!' do
    it 'creates a new vault with new password preserving credentials' do
      storage.create_new!(salt)
      cred = Enigma::Core::Vault::Credential.new(site: 'S', username: 'u', password: 'p')
      storage.save([cred])

      new_password = 'new-password-123'
      new_keys = described_class.reencrypt!(cipher, new_password, nil, tmp_path)

      expect(new_keys[:vault_key].bytesize).to eq(32)
      expect(new_keys[:filelock_key].bytesize).to eq(32)

      new_cipher = Enigma::Core::Cipher::AesGcm.new(new_keys[:vault_key])
      new_storage = described_class.new(tmp_path, new_cipher)
      loaded = new_storage.load
      expect(loaded.size).to eq(1)
      expect(loaded.first.site).to eq('S')
    end

    it 'is atomic — vault still readable after reencryption with new key' do
      storage.create_new!(salt)
      cred = Enigma::Core::Vault::Credential.new(site: 'S', username: 'u', password: 'p')
      storage.save([cred])

      original_raw = File.binread(tmp_path)

      new_keys = described_class.reencrypt!(cipher, 'new-password-456', nil, tmp_path)
      expect(File.exist?(tmp_path)).to be true

      new_cipher = Enigma::Core::Cipher::AesGcm.new(new_keys[:vault_key])
      new_storage = described_class.new(tmp_path, new_cipher)
      loaded = new_storage.load
      expect(loaded.size).to eq(1)
      expect(loaded.first.site).to eq('S')

      raw = File.binread(tmp_path)
      expect(raw).not_to eq(original_raw)
    end
  end
end
