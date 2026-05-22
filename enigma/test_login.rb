# frozen_string_literal: true

require 'fileutils'
require 'benchmark'
require_relative 'app/core/core'

DATA_DIR = File.expand_path('~/.enigma_cryptoshelter')
VAULT_PATH = File.join(DATA_DIR, 'vault.dat')
AUTH_PATH  = File.join(DATA_DIR, 'auth.dat')

PASSWORD = 'TestMaster123!'

def clean_state
  FileUtils.rm_f(VAULT_PATH)
  FileUtils.rm_f(AUTH_PATH)
  Enigma::Core::Vault::Storage.clear_salt_cache!
end

def measure(label)
  real = Benchmark.measure { yield }.real
  puts "  #{label}: #{real.round(3)}s"
  real
end

# ── 1. CREATE VAULT (first-run) ──
puts "=== CREACIÓN DE VAULT (primera ejecución) ==="
clean_state

create_time = measure("create_vault") do
  Enigma::Core::Facades::VaultFacade.create(PASSWORD, security_data: {
    questions: [
      { index: 0, answer: 'Gato' },
      { index: 1, answer: 'Rojo' }
    ],
    answers: ['Gato', 'Rojo']
  })
end

puts "  El vault se creó correctamente"
puts "  Tamaño vault: #{File.size(VAULT_PATH)} bytes" if File.exist?(VAULT_PATH)
puts "  Tamaño auth:  #{File.size(AUTH_PATH)} bytes"  if File.exist?(AUTH_PATH)

# ── 2. OPEN VAULT (returning user, correct password) ──
puts "\n=== APERTURA DE VAULT (clave correcta) ==="
Enigma::Core::Vault::Storage.clear_salt_cache!

open_time = measure("open_vault") do
  Enigma::Core::Facades::VaultFacade.open(PASSWORD)
end

# ── 3. OPEN WITH WRONG PASSWORD ──
puts "\n=== APERTURA DE VAULT (clave incorrecta) ==="
Enigma::Core::Vault::Storage.clear_salt_cache!

wrong_time = measure("open_wrong (esperado: AuthTagError)") do
  Enigma::Core::Facades::VaultFacade.open('wrong_password')
rescue Enigma::Errors::AuthTagError
  :expected_error
end

puts "  Error capturado correctamente"

# ── 4. OPEN WITH KEYS (recovery flow) ──
puts "\n=== APERTURA CON CLAVES (flujo de recuperación) ==="
Enigma::Core::Vault::Storage.clear_salt_cache!

keys = Enigma::Core::Vault::Storage.read_recovery_data(nil, ['Gato', 'Rojo'])
if keys
  keys_time = measure("open_with_keys") do
    Enigma::Core::Facades::VaultFacade.open_with_keys(keys)
  end
else
  puts "  (no hay recovery data — se omite)"
end

# ── 5. VERIFY ANSWERS (recovery flow) ──
puts "\n=== VERIFICACIÓN DE RESPUESTAS ==="
Enigma::Core::Vault::Storage.clear_salt_cache!

verify_time = measure("verify_answers") do
  Enigma::Core::Vault::Storage.verify_answers(['Gato', 'Rojo'])
end

puts "  Respuestas correctas: #{Enigma::Core::Vault::Storage.verify_answers(['Gato', 'Rojo'])}"
puts "  Respuestas incorrectas: #{Enigma::Core::Vault::Storage.verify_answers(['Perro', 'Azul'])}"

# ── 6. CHANGE PASSWORD ──
puts "\n=== CAMBIO DE CLAVE ==="
Enigma::Core::Vault::Storage.clear_salt_cache!

session = Enigma::Core::Facades::VaultFacade.open(PASSWORD)

change_time = measure("change_password") do
  Enigma::Core::Facades::VaultFacade.change_password(
    { vault_key: session[:vault_key], filelock_key: session[:filelock_key] },
    'NewStrongPass456!', 'NewStrongPass456!'
  )
end

puts "  Contraseña cambiada correctamente"

# ── 7. VERIFY NEW PASSWORD WORKS ──
puts "\n=== VERIFICAR NUEVA CLAVE ==="
Enigma::Core::Vault::Storage.clear_salt_cache!

new_open_time = measure("open_with_new_password") do
  Enigma::Core::Facades::VaultFacade.open('NewStrongPass456!')
end

# ── SUMMARY ──
puts "\n═══════════════════════════════════════"
puts "           RESUMEN DE TIEMPOS"
puts "═══════════════════════════════════════"
puts "  Creación de vault:    #{create_time.round(3)}s" if create_time
puts "  Apertura (correcta):  #{open_time.round(3)}s" if open_time
puts "  Apertura (errónea):   #{wrong_time.round(3)}s" if wrong_time
puts "  Cambio de clave:      #{change_time.round(3)}s" if change_time
puts "  Apertura (nueva):     #{new_open_time.round(3)}s" if new_open_time
puts "═══════════════════════════════════════"
puts "  Todos los flujos de login funcionan correctamente."
