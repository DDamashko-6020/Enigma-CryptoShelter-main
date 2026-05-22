# frozen_string_literal: true

$LOAD_PATH.unshift File.join(__dir__, '..')
$LOAD_PATH.unshift File.join(__dir__, '..', 'app')

require 'core/core'
require 'utils/password_generator'
require 'utils/validator'
require 'utils/file_handler'

RSpec.configure do |config|
  config.after(:each) do
    Enigma::Core::Vault::Storage.clear_salt_cache!
  end
end

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    minimum_coverage 70
    add_group 'Cipher',   'app/core/cipher'
    add_group 'Vault',    'app/core/vault'
    add_group 'FileLock', 'app/core/file_lock'
    add_group 'Utils',    'utils'
  end
end
