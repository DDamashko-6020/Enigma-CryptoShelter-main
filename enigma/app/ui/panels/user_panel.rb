# frozen_string_literal: true

#
# app/ui/panels/user_panel.rb
# Responsibility: User settings modal — change password, vault info.
# Uses Queue + TkAfter polling (Thread-safe).
#

require 'tk'

module Enigma
  module UI
    module Panels
      class UserPanel < TkToplevel
        COLORS = Theme::COLORS
        FONT   = Theme::FONT

        def initialize(parent, opts = {})
          super(parent)
          @session            = opts[:session]
          @on_session_update  = opts[:on_session_update]
          configure_window
          build_ui
        end

        private

        def configure_window
          title 'Enigma — Perfil de Usuario'
          geometry '500x600'
          resizable(false, false)
          configure(background: COLORS[:bg_main])

          update
          x = (winfo_screenwidth - 500) / 2
          y = (winfo_screenheight - 600) / 2
          geometry("500x600+#{x}+#{y}")
        end

        def build_ui
          build_header
          build_change_password_section
          build_divider
          build_change_questions_section
          build_divider
          build_vault_info_section
          build_close_button
        end

        def build_header
          TkFrame.new(self) do
            background COLORS[:bg_panel]
            height 60
          end.tap do |f|
            f.pack(fill: :x)
            f.pack_propagate(false)

            TkLabel.new(f) do
              text '👤 PERFIL DE USUARIO'
              foreground COLORS[:orange]
              background COLORS[:bg_panel]
              font TkFont.new("#{FONT} 14 bold")
            end.place(relx: 0.5, rely: 0.5, anchor: 'center')
          end
        end

        def build_change_password_section
          section = build_section('CAMBIAR CLAVE MAESTRA')

          build_field(section, 'CLAVE ACTUAL', masked: true) do |var, _entry|
            @current_pass_var = var
          end

          build_field(section, 'NUEVA CLAVE', masked: true) do |var, _entry|
            @new_pass_var = var
            var.trace('w') { update_strength_label(var.value) }
          end

          build_field(section, 'CONFIRMAR NUEVA CLAVE', masked: true) do |var, _entry|
            @confirm_pass_var = var
          end

          @strength_label = TkLabel.new(section) do
            text ''
            background COLORS[:bg_main]
            font TkFont.new("#{FONT} 9")
          end
          @strength_label.pack(anchor: 'w', padx: 16, pady: [0, 4])

          @pass_error = TkLabel.new(section) do
            text ''
            foreground COLORS[:red_err]
            background COLORS[:bg_main]
            font TkFont.new("#{FONT} 9")
          end
          @pass_error.pack(anchor: 'w', padx: 16, pady: [0, 8])

          @change_pass_btn = TkButton.new(section) do
            text 'CAMBIAR CLAVE'
            background COLORS[:orange]
            foreground COLORS[:bg_main]
            relief 'flat'
            font TkFont.new("#{FONT} 10 bold")
            cursor 'hand2'
            padx 16
            pady 6
          end
          @change_pass_btn.command = -> { on_change_password }
          @change_pass_btn.pack(anchor: 'e', padx: 16, pady: [0, 16])
        end

        def build_change_questions_section
          section = build_section('PREGUNTAS DE SEGURIDAD')

          TkLabel.new(section) do
            text 'Actualiza tus preguntas de recuperación'
            foreground COLORS[:fg_secondary]
            background COLORS[:bg_main]
            font TkFont.new("#{FONT} 9")
          end.pack(anchor: 'w', padx: 16, pady: [0, 8])

          TkButton.new(section) do
            text 'CAMBIAR PREGUNTAS'
            background COLORS[:bg_main]
            foreground COLORS[:orange]
            relief 'flat'
            font TkFont.new("#{FONT} 10 bold")
            cursor 'hand2'
            padx 16
            pady 6
            highlightthickness 1
            highlightcolor COLORS[:orange]
            highlightbackground COLORS[:orange]
          end.tap do |b|
            b.command = -> { on_change_questions }
            b.pack(anchor: 'e', padx: 16, pady: [0, 16])
          end
        end

        def build_vault_info_section
          section = build_section('INFORMACIÓN DEL VAULT')

          vault_path = Core::Vault::Storage::VAULT_PATH
          exists     = File.exist?(vault_path)
          size       = exists ? "#{File.size(vault_path)} bytes" : 'N/A'
          perms      = exists ? format('%o', File.stat(vault_path).mode)[-3..] : 'N/A'
          count      = @session[:manager]&.count || 0

          [
            ['Ubicación',      vault_path],
            ['Tamaño',         size],
            ['Permisos',       perms],
            ['Credenciales',   count.to_s],
            ['Cifrado',        'AES-256-GCM'],
            ['Derivación',     'PBKDF2 / 600,000 iteraciones']
          ].each do |label, value|
            row = TkFrame.new(section) { background COLORS[:bg_main] }
            row.pack(fill: :x, padx: 16, pady: 2)

            TkLabel.new(row) do
              text "#{label}:"
              foreground COLORS[:fg_secondary]
              background COLORS[:bg_main]
              font TkFont.new("#{FONT} 9")
              width 16
              anchor 'w'
            end.pack(side: :left)

            TkLabel.new(row) do
              text value
              foreground COLORS[:fg_primary]
              background COLORS[:bg_main]
              font TkFont.new("#{FONT} 9")
              anchor 'w'
            end.pack(side: :left, fill: :x, expand: true)
          end

          TkFrame.new(section) do
            background COLORS[:bg_main]
            height 16
          end
                 .pack(fill: :x)
        end

        def build_close_button
          TkButton.new(self) do
            text '← CERRAR'
            background COLORS[:bg_main]
            foreground COLORS[:orange]
            relief 'flat'
            font TkFont.new("#{FONT} 10 bold")
            cursor 'hand2'
            padx 20
            pady 8
          end.tap do |b|
            b.command = -> { destroy }
            b.pack(side: :bottom, anchor: 'w', padx: 16, pady: 16)
          end
        end

        def on_change_password
          current = @current_pass_var.value
          new_p   = @new_pass_var.value
          confirm = @confirm_pass_var.value

          if current.empty? || new_p.empty? || confirm.empty?
            @pass_error.configure(text: 'Completa todos los campos')
            return
          end

          @pass_error.configure(text: '')
          @change_pass_btn.configure(text: 'Cambiando...', state: 'disabled')
          @change_pass_btn.update

          @pass_queue = Queue.new

          Thread.new do
            current_keys = verify_current_password!(current)
            new_session = Core::Facades::VaultFacade.change_password(
              current_keys, new_p, confirm
            )
            Core::Auth::AuthConfig.new.reset_master_password(new_p) if File.exist?(Core::Auth::AuthConfig::AUTH_PATH)
            @pass_queue << [:ok, new_session]
          rescue Errors::AuthTagError
            @pass_queue << [:error, 'Clave actual incorrecta']
          rescue Errors::VaultError, Errors::InvalidKeyError => e
            @pass_queue << [:error, e.message]
          rescue StandardError => e
            @pass_queue << [:error, "Error: #{e.message}"]
          end

          poll_pass_queue
        end

        def on_change_questions
          Tk.messageBox(
            type: 'ok', icon: 'info',
            title: 'Próximamente',
            message: "Actualización de preguntas disponible\nen la próxima versión."
          )
        end

        def poll_pass_queue
          result = begin
            @pass_queue.pop(true)
          rescue ThreadError
            nil
          end

          if result.nil?
            TkAfter.new(100, 1) { poll_pass_queue }.start
            return
          end

          case result[0]
          when :ok
            @session = result[1]
            @on_session_update.call(result[1])
            show_success('Clave cambiada correctamente')
            clear_password_fields
          when :error
            @pass_error.configure(text: result[1])
          end

          @change_pass_btn.configure(text: 'CAMBIAR CLAVE', state: 'normal')
        end

        def verify_current_password!(password)
          salt = Core::Vault::Storage.read_salt(Core::Vault::Storage::VAULT_PATH)
          keys = Core::KeyMaster.instance.derive_session_keys(password, salt)
          test_cipher = Core::Cipher::AesGcm.new(keys[:vault_key])
          test_storage = Core::Vault::Storage.new(
            Core::Vault::Storage::VAULT_PATH, test_cipher
          )
          test_storage.load
          keys
        rescue Errors::AuthTagError
          raise Errors::AuthTagError, 'Clave actual incorrecta'
        end

        def update_strength_label(password)
          return @strength_label.configure(text: '') if password.empty?

          level = Utils::PasswordGenerator.strength(password)
          color = { weak: COLORS[:red_err], medium: COLORS[:orange], strong: COLORS[:green_ok] }[level]
          label = { weak: 'Débil', medium: 'Media', strong: 'Fuerte' }[level]
          @strength_label.configure(text: "Seguridad: #{label}", foreground: color)
        end

        def clear_password_fields
          [@current_pass_var, @new_pass_var, @confirm_pass_var].each { |v| v.value = '' }
          @strength_label.configure(text: '')
        end

        def show_success(message)
          Tk.messageBox(type: 'ok', icon: 'info', title: 'Éxito', message: message)
        end

        def build_section(title)
          TkLabel.new(self) do
            text title
            foreground COLORS[:orange]
            background COLORS[:bg_main]
            font TkFont.new("#{FONT} 9 bold")
            anchor 'w'
            padx 16
            pady 8
          end.pack(fill: :x)

          TkFrame.new(self) { background COLORS[:bg_main] }
                 .tap { |f| f.pack(fill: :x) }
        end

        def build_divider
          TkFrame.new(self) do
            background COLORS[:border]
            height 1
          end.pack(fill: :x, pady: 4)
        end

        def build_field(parent, label, masked: false, &block)
          TkLabel.new(parent) do
            text label
            foreground COLORS[:fg_secondary]
            background COLORS[:bg_main]
            font TkFont.new("#{FONT} 9")
          end.pack(anchor: 'w', padx: 16, pady: [4, 0])

          frame = TkFrame.new(parent) { background COLORS[:bg_main] }
          frame.pack(fill: :x, padx: 16, pady: [2, 8])

          var   = TkVariable.new('')
          entry = TkEntry.new(frame) do
            textvariable var
            show masked ? '*' : ''
            background COLORS[:bg_input]
            foreground COLORS[:fg_primary]
            insertbackground COLORS[:orange]
            relief 'flat'
            font TkFont.new("#{FONT} 11")
            highlightthickness 1
            highlightcolor COLORS[:orange]
            highlightbackground COLORS[:border]
          end
          entry.pack(side: :left, fill: :x, expand: true, ipady: 4)

          if masked
            show_state = false
            btn = TkButton.new(frame) do
              text '👁'
              background COLORS[:bg_main]
              foreground COLORS[:fg_secondary]
              relief 'flat'
              cursor 'hand2'
              width 3
            end
            btn.command = lambda {
              show_state = !show_state
              entry.configure(show: show_state ? '' : '*')
              btn.configure(foreground: show_state ? COLORS[:orange] : COLORS[:fg_secondary])
            }
            btn.pack(side: :right, padx: [4, 0])
          end

          block&.call(var, entry)
        end
      end
    end
  end
end
