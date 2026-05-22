# frozen_string_literal: true

#
# app/ui/screens/change_password_screen.rb
# Responsibility: Set new master password after identity verification (recovery flow).
# Accepts pre-derived current_keys (recovered from security answers).
# ONE PBKDF2 call for new password only.
#

require 'tk'

module Enigma
  module UI
    class ChangePasswordScreen
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(parent, on_back:, on_success:, current_keys:)
        @parent       = parent
        @on_back      = on_back
        @on_success   = on_success
        @current_keys = current_keys
        build
      end

      def hide
        @frame.pack_forget
      end

      private

      def build
        @frame = TkFrame.new(@parent) { background COLORS[:bg_main] }
        @frame.pack(expand: true, fill: :both)

        card = TkFrame.new(@frame) { background COLORS[:bg_panel] }
        card.place(relx: 0.5, rely: 0.5, anchor: 'center')

        TkLabel.new(card) do
          text '🔑 NUEVA CLAVE MAESTRA'
          font TkFont.new("#{FONT} 14 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end.pack(pady: [20, 4])

        TkLabel.new(card) do
          text 'Tus contraseñas serán preservadas con el nuevo cifrado'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:green_ok]
          background COLORS[:bg_panel]
        end.pack(pady: [0, 20])

        build_new_password_field(card)
        build_confirm_field(card)
        build_error_label(card)
        build_buttons(card)
      end

      def build_new_password_field(parent)
        TkLabel.new(parent) do
          text '  NUEVA CLAVE MAESTRA'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end.pack(anchor: 'w', padx: 30)

        frame = TkFrame.new(parent) { background COLORS[:bg_panel] }
        frame.pack(fill: :x, padx: 30, pady: [4, 8])

        @new_pass_var = TkVariable.new('')
        @new_pass_entry = TkEntry.new(frame) do
          textvariable @new_pass_var
          show '*'
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          insertbackground COLORS[:orange]
          relief 'flat'
          font TkFont.new("#{FONT} 11")
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        @new_pass_entry.pack(side: :left, fill: :x, expand: true, ipady: 4)
        @new_pass_var.trace('w') { update_strength }
        build_eye_toggle(frame, @new_pass_entry)
      end

      def build_confirm_field(parent)
        TkLabel.new(parent) do
          text '  CONFIRMAR NUEVA CLAVE'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end.pack(anchor: 'w', padx: 30)

        frame = TkFrame.new(parent) { background COLORS[:bg_panel] }
        frame.pack(fill: :x, padx: 30, pady: [4, 8])

        @confirm_var = TkVariable.new('')
        entry = TkEntry.new(frame) do
          textvariable @confirm_var
          show '*'
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
        build_eye_toggle(frame, entry)

        @strength_label = TkLabel.new(frame) do
          text ''
          background COLORS[:bg_panel]
          font TkFont.new("#{FONT} 9")
        end
      end

      def build_error_label(parent)
        @error_label = TkLabel.new(parent) do
          text ''
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:red_err]
          background COLORS[:bg_panel]
        end
        @error_label.pack(anchor: 'w', padx: 30, pady: [4, 0])
      end

      def build_buttons(parent)
        btn_frame = TkFrame.new(parent) { background COLORS[:bg_panel] }
        btn_frame.pack(fill: :x, padx: 30, pady: [12, 20])

        TkButton.new(btn_frame) do
          text '← VOLVER'
          background COLORS[:bg_panel]
          foreground COLORS[:orange]
          relief 'flat'
          font TkFont.new("#{FONT} 10 bold")
          cursor 'hand2'
        end.tap do |b|
          b.command = -> { hide; @on_back.call }
          b.pack(side: :left)
        end

        @change_btn = TkButton.new(btn_frame) do
          text 'CAMBIAR CLAVE'
          background COLORS[:orange]
          foreground COLORS[:bg_main]
          relief 'flat'
          font TkFont.new("#{FONT} 11 bold")
          cursor 'hand2'
          padx 20
          pady 8
        end
        @change_btn.command = -> { on_change }
        @change_btn.pack(side: :right)
      end

      def on_change
        new_pass = @new_pass_var.value
        confirm  = @confirm_var.value

        return @error_label.configure(text: 'Mínimo 8 caracteres') if new_pass.length < 8
        return @error_label.configure(text: 'Las claves no coinciden') if new_pass != confirm

        @error_label.configure(text: '')
        @change_btn.configure(text: 'Cambiando...', state: 'disabled')

        @change_queue = Queue.new

        Thread.new do
          new_session = Core::Facades::VaultFacade.change_password(
            @current_keys, new_pass, confirm
          )
          @change_queue << [:ok, new_session]
        rescue Errors::AuthTagError
          @change_queue << [:error, 'Error al descifrar vault. Intenta de nuevo.']
        rescue Errors::VaultError, Errors::InvalidKeyError => e
          @change_queue << [:error, e.message]
        rescue => e
          @change_queue << [:error, "Error: #{e.message}"]
        end

        poll_change_queue
      end

      def poll_change_queue
        result = begin
          @change_queue.pop(true)
        rescue ThreadError
          nil
        end

        if result.nil?
          TkAfter.new(100, 1) { poll_change_queue }.start
          return
        end

        case result[0]
        when :ok
          @on_success.call(result[1])
        when :error
          @error_label.configure(text: result[1])
          @change_btn.configure(text: 'CAMBIAR CLAVE', state: 'normal')
        end
      end

      def update_strength
        pass = @new_pass_var.value
        return @strength_label.configure(text: '') if pass.empty?

        level = Utils::PasswordGenerator.strength(pass)
        color = { weak: COLORS[:red_err], medium: COLORS[:orange], strong: COLORS[:green_ok] }[level]
        label = { weak: 'Débil', medium: 'Media', strong: 'Fuerte' }[level]
        @strength_label.configure(text: "  Seguridad: #{label}", foreground: color)
      end

      def build_eye_toggle(parent, entry)
        show = false
        btn = TkButton.new(parent) do
          text '👁'
          background COLORS[:bg_panel]
          foreground COLORS[:fg_secondary]
          relief 'flat'
          cursor 'hand2'
          width 3
        end
        btn.command = lambda {
          show = !show
          entry.configure(show: show ? '' : '*')
          btn.configure(foreground: show ? COLORS[:orange] : COLORS[:fg_secondary])
        }
        btn.pack(side: :right, padx: [4, 0])
      end
    end
  end
end
