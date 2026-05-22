# frozen_string_literal: true

require 'tempfile'
require 'securerandom'

RSpec.describe Enigma::Utils::FileHandler do
  let(:tmp) { Tempfile.new('handler_test') }

  after { tmp.unlink }

  describe '.read' do
    it 'reads file content correctly' do
      tmp.write('contenido de prueba')
      tmp.close
      expect(described_class.read(tmp.path)).to eq('contenido de prueba')
    end

    it 'raises Errno::ENOENT for missing file' do
      expect { described_class.read('/no/existe/ruta.txt') }
        .to raise_error(Errno::ENOENT)
    end
  end

  describe '.write' do
    it 'writes and reads back binary content' do
      binary = SecureRandom.random_bytes(256)
      described_class.write(tmp.path, binary)
      expect(described_class.read(tmp.path)).to eq(binary)
    end

    it 'sets restrictive permissions' do
      described_class.write(tmp.path, 'data')
      mode = File.stat(tmp.path).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end

  describe '.exist?' do
    it 'returns true for existing file' do
      expect(described_class.exist?(tmp.path)).to be true
    end

    it 'returns false for missing file' do
      expect(described_class.exist?('/no/existe/ruta.txt')).to be false
    end
  end

  describe '.delete' do
    it 'removes the file' do
      described_class.delete(tmp.path)
      expect(File.exist?(tmp.path)).to be false
    end

    it 'does not raise for missing file' do
      expect { described_class.delete('/no/existe/ruta.txt') }.not_to raise_error
    end
  end
end
