# frozen_string_literal: true

RSpec.describe Enigma::Core::Vault::Manager do
  let(:tmp_path) { File.join('/tmp', "enigma_vault_test_#{Time.now.to_i}_#{rand(9999)}.vault") }
  let(:password) { 'master-password' }
  let(:salt) { SecureRandom.random_bytes(32) }
  let(:vault_key) { Enigma::Core::KeyMaster.instance.derive_session_keys(password, salt)[:vault_key] }
  let(:cipher) { Enigma::Core::Cipher::AesGcm.new(vault_key) }
  let(:storage) { Enigma::Core::Vault::Storage.new(tmp_path, cipher) }
  subject(:manager) { described_class.new(storage) }

  before do
    FileUtils.rm_f(tmp_path)
    storage.create_new!(salt)
  end

  after(:each) { FileUtils.rm_f(tmp_path) if File.exist?(tmp_path) }

  describe 'initial state' do
    it 'starts locked' do
      expect(manager.unlocked?).to be false
    end
  end

  describe '#unlock' do
    it 'unlocks a new vault' do
      manager.unlock
      expect(manager.unlocked?).to be true
    end

    it 'persists an empty vault file' do
      manager.unlock
      expect(File.exist?(tmp_path)).to be true
    end
  end

  describe 'CRUD when locked' do
    it 'all raises VaultLockedError' do
      expect { manager.all }.to raise_error(Enigma::Errors::VaultLockedError)
    end

    it 'add raises VaultLockedError' do
      expect { manager.add(site: 'S', username: 'u', password: 'p') }
        .to raise_error(Enigma::Errors::VaultLockedError)
    end

    it 'find raises VaultLockedError' do
      expect { manager.find('test') }.to raise_error(Enigma::Errors::VaultLockedError)
    end

    it 'delete raises VaultLockedError' do
      expect { manager.delete('id') }.to raise_error(Enigma::Errors::VaultLockedError)
    end
  end

  describe 'CRUD when unlocked' do
    before { manager.unlock }

    describe '#add' do
      it 'adds a credential and increases count' do
        manager.add(site: 'GitHub', username: 'user', password: 'pass')
        expect(manager.count).to eq(1)
      end

      it 'returns the created credential' do
        cred = manager.add(site: 'S', username: 'u', password: 'p')
        expect(cred).to be_a(Enigma::Core::Vault::Credential)
        expect(cred.site).to eq('S')
      end

      it 'persists to storage' do
        manager.add(site: 'A', username: 'u', password: 'p')
        new_manager = described_class.new(storage)
        new_manager.unlock
        expect(new_manager.count).to eq(1)
      end
    end

    describe '#all' do
      it 'returns empty array initially' do
        expect(manager.all).to eq([])
      end

      it 'returns defensive copy' do
        manager.add(site: 'S', username: 'u', password: 'p')
        all = manager.all
        all.clear
        expect(manager.count).to eq(1)
      end
    end

    describe '#find' do
      before do
        manager.add(site: 'GitHub', username: 'dev', password: 'p1')
        manager.add(site: 'GitLab', username: 'dev', password: 'p2')
        manager.add(site: 'AWS', username: 'root', password: 'p3')
      end

      it 'finds by partial site match' do
        results = manager.find('git')
        expect(results.size).to eq(2)
        expect(results.map(&:site)).to contain_exactly('GitHub', 'GitLab')
      end

      it 'finds by partial username match' do
        results = manager.find('root')
        expect(results.size).to eq(1)
        expect(results.first.site).to eq('AWS')
      end

      it 'returns empty array for no match' do
        expect(manager.find('zzzz')).to eq([])
      end

      it 'is case insensitive' do
        expect(manager.find('GITHUB').size).to eq(1)
      end
    end

    describe '#update' do
      it 'updates fields' do
        cred = manager.add(site: 'S', username: 'u', password: 'p')
        updated = manager.update(cred.id, username: 'newuser', notes: 'updated')
        expect(updated.username).to eq('newuser')
        expect(updated.notes).to eq('updated')
      end

      it 'preserves id and created_at' do
        cred = manager.add(site: 'S', username: 'u', password: 'p')
        updated = manager.update(cred.id, site: 'NewSite')
        expect(updated.id).to eq(cred.id)
        expect(updated.created_at).to eq(cred.created_at)
      end

      it 'updates updated_at' do
        cred = manager.add(site: 'S', username: 'u', password: 'p')
        old_time = cred.updated_at
        sleep 1
        updated = manager.update(cred.id, site: 'NewSite')
        expect(updated.updated_at).not_to eq(old_time)
      end

      it 'raises CredentialNotFoundError for unknown id' do
        expect { manager.update('bad-id', site: 'X') }
          .to raise_error(Enigma::Errors::CredentialNotFoundError)
      end
    end

    describe '#delete' do
      it 'removes credential' do
        cred = manager.add(site: 'S', username: 'u', password: 'p')
        manager.delete(cred.id)
        expect(manager.count).to eq(0)
      end

      it 'raises CredentialNotFoundError for unknown id' do
        expect { manager.delete('bad-id') }
          .to raise_error(Enigma::Errors::CredentialNotFoundError)
      end

      it 'persists deletion' do
        cred = manager.add(site: 'S', username: 'u', password: 'p')
        manager.delete(cred.id)
        new_manager = described_class.new(storage)
        new_manager.unlock
        expect(new_manager.count).to eq(0)
      end
    end

    describe '#lock' do
      it 'locks the vault and clears credentials' do
        manager.add(site: 'S', username: 'u', password: 'p')
        manager.lock
        expect(manager.unlocked?).to be false
      end

      it 'prevents further CRUD' do
        manager.add(site: 'S', username: 'u', password: 'p')
        manager.lock
        expect { manager.all }.to raise_error(Enigma::Errors::VaultLockedError)
      end
    end
  end
end
