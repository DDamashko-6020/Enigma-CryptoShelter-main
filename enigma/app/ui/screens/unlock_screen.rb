# frozen_string_literal: true

require 'tk'

module Enigma
  module UI
    class UnlockScreen
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(root, on_success, on_recovery = nil)
        @root        = root
        @on_success  = on_success
        @on_recovery = on_recovery
        build
      end

      def hide
        @frame.pack_forget
      end

      private

      def build
        @root.geometry('420x360+200+150')
        @root.resizable(false, false)

        @frame = TkFrame.new(@root) { background COLORS[:bg_main] }
        @frame.pack(expand: true)

        title = TkLabel.new(@frame) do
          text '🔒  ENIGMA CRYPTOSHELTER'
          font TkFont.new("#{FONT} 14 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
        end
        title.pack(pady: [0, 4])

        subtitle = TkLabel.new(@frame) do
          text 'Ingresa tu clave maestra'
          font TkFont.new("#{FONT} 10")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end
        subtitle.pack(pady: [0, 20])

        pw_card = TkFrame.new(@frame) { background COLORS[:bg_panel] }
        pw_card.pack(fill: :x, padx: 40)

        pw_label = TkLabel.new(pw_card) do
          text '  Clave maestra'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end
        pw_label.pack(anchor: 'w', padx: 16, pady: [16, 0])

        pw_row = TkFrame.new(pw_card) { background COLORS[:bg_panel] }
        pw_row.pack(fill: :x, padx: 16, pady: [4, 16])

        @pw_entry = TkEntry.new(pw_row) do
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 11")
          insertbackground COLORS[:orange]
          show '*'
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        @pw_entry.pack(side: :left, fill: :x, expand: true, ipady: 4)
        @pw_entry.focus

        toggle_btn = TkLabel.new(pw_row) do
          text '  👁  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 11)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        toggle_btn.pack(side: :left)
        toggle_btn.bind('Button-1') { toggle_password }

        @error_label = TkLabel.new(@frame) do
          text ''
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:red_err]
          background COLORS[:bg_main]
        end
        @error_label.pack(anchor: 'w', padx: 40, pady: [4, 0])

        btn_frame = TkFrame.new(@frame) { background COLORS[:bg_main] }
        btn_frame.pack(pady: [12, 0])

        @unlock_btn = TkButton.new(btn_frame) do
          text '  ABRIR VAULT  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:bg_main]
          background COLORS[:orange]
          relief 'flat'
        end
        @unlock_btn.pack(fill: :x, padx: 40, ipady: 6)

        @unlock_btn.command(proc { on_unlock })
        @pw_entry.bind('Return') { on_unlock }

        recovery_link = TkLabel.new(@frame) do
          text '  ¿Olvidaste tu clave? Recupérala aquí  '
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
          cursor 'hand2'
        end
        recovery_link.pack(pady: [12, 0])
        recovery_link.bind('Button-1') { @on_recovery&.call }
      end

      def on_unlock
        pw = @pw_entry.value.strip
        if pw.empty?
          show_inline_error('Ingresa tu clave maestra')
          return
        end

        @unlock_btn.configure(text: '  Verificando...  ', state: 'disabled')
        @error_label.configure(text: '')
        @unlock_btn.update

        Thread.new do
          begin
            session = Core::Facades::VaultFacade.open(pw)
            TkAfter.new(0, 1) { @on_success.call(session) }.start
          rescue Errors::AuthTagError
            TkAfter.new(0, 1) do
              show_inline_error('Clave incorrecta')
              @unlock_btn.configure(text: '  ABRIR VAULT  ', state: 'normal')
              @pw_entry.delete(0, 'end')
              @pw_entry.focus
            end.start
          rescue => e
            TkAfter.new(0, 1) do
              show_inline_error("Error: #{e.message}")
              @unlock_btn.configure(text: '  ABRIR VAULT  ', state: 'normal')
            end.start
          end
        end
      end

      def show_inline_error(message)
        @error_label.configure(text: "  #{message}", foreground: COLORS[:red_err])
      end

      def toggle_password
        current = @pw_entry.cget('show')
        @pw_entry.configure('show' => current == '*' ? '' : '*')
      end
    end
  end
end
