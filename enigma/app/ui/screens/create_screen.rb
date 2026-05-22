# frozen_string_literal: true

require 'tk'

module Enigma
  module UI
    class CreateScreen
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(root, on_success)
        @root       = root
        @on_success = on_success
        build
      end

      def hide
        @frame.pack_forget
      end

      private

      def build
        @root.geometry('420x400+200+150')
        @root.resizable(false, false)

        @frame = TkFrame.new(@root) { background COLORS[:bg_main] }
        @frame.pack(expand: true, fill: :both)

        canvas = TkFrame.new(@frame) { background COLORS[:bg_main] }
        canvas.pack(expand: true, pady: [20, 0])

        title = TkLabel.new(canvas) do
          text '🔒  ENIGMA CRYPTOSHELTER'
          font TkFont.new("#{FONT} 14 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
        end
        title.pack(pady: [0, 4])

        subtitle = TkLabel.new(canvas) do
          text 'Crear clave maestra'
          font TkFont.new("#{FONT} 10")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end
        subtitle.pack(pady: [0, 16])

        build_password_fields(canvas)
        build_strength_bar(canvas)
        build_error_label(canvas)
        build_create_button(canvas)
      end

      def build_password_fields(parent)
        pw_card = TkFrame.new(parent) { background COLORS[:bg_panel] }
        pw_card.pack(fill: :x, padx: 40)

        pw_label = TkLabel.new(pw_card) do
          text '  Clave maestra'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end
        pw_label.pack(anchor: 'w', padx: 16, pady: [16, 0])

        pw_row = TkFrame.new(pw_card) { background COLORS[:bg_panel] }
        pw_row.pack(fill: :x, padx: 16, pady: [4, 0])

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

        toggle_pw = TkLabel.new(pw_row) do
          text '  👁  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 11)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        toggle_pw.pack(side: :left)
        toggle_pw.bind('Button-1') { toggle_password }

        confirm_label = TkLabel.new(pw_card) do
          text '  Confirmar clave maestra'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end
        confirm_label.pack(anchor: 'w', padx: 16, pady: [12, 0])

        confirm_row = TkFrame.new(pw_card) { background COLORS[:bg_panel] }
        confirm_row.pack(fill: :x, padx: 16, pady: [4, 16])

        @confirm_entry = TkEntry.new(confirm_row) do
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
        @confirm_entry.pack(side: :left, fill: :x, expand: true, ipady: 4)

        toggle_confirm = TkLabel.new(confirm_row) do
          text '  👁  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 11)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        toggle_confirm.pack(side: :left)
        toggle_confirm.bind('Button-1') { toggle_confirm_visibility }
      end

      def build_strength_bar(parent)
        @strength_label = TkLabel.new(parent) do
          text ''
          font TkFont.new("#{FONT} 9")
          background COLORS[:bg_main]
        end
        @strength_label.pack(anchor: 'w', padx: 40, pady: [4, 0])

        @pw_entry.bind('KeyRelease') { update_strength }
      end

      def build_error_label(parent)
        @error_label = TkLabel.new(parent) do
          text ''
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:red_err]
          background COLORS[:bg_main]
        end
        @error_label.pack(anchor: 'w', padx: 40, pady: [4, 0])
      end

      def build_create_button(parent)
        btn_frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        btn_frame.pack(pady: [8, 20])

        @create_btn = TkButton.new(btn_frame) do
          text '  CREAR VAULT  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:bg_main]
          background COLORS[:orange]
          relief 'flat'
        end
        @create_btn.pack(fill: :x, padx: 40, ipady: 6)

        @create_btn.command(proc { on_create })
      end

      def on_create
        pw = @pw_entry.value
        confirm = @confirm_entry.value
        return show_error('Mínimo 8 caracteres') if pw.length < 8
        return show_error('Las claves no coinciden') if pw != confirm

        @create_btn.configure(text: '  Creando vault...  ', state: 'disabled')
        @error_label.configure(text: '')
        @create_btn.update

        Thread.new do
          begin
            session = Core::Facades::VaultFacade.create(pw)
            TkAfter.new(0, 1) { @on_success.call(session) }.start
          rescue => e
            TkAfter.new(0, 1) do
              show_error("Error: #{e.message}")
              @create_btn.configure(text: '  CREAR VAULT  ', state: 'normal')
            end.start
          end
        end
      end

      def show_error(msg)
        @error_label.configure('text' => "  #{msg}", foreground: COLORS[:red_err])
      end

      def toggle_password
        current = @pw_entry.cget('show')
        @pw_entry.configure('show' => current == '*' ? '' : '*')
      end

      def toggle_confirm_visibility
        current = @confirm_entry.cget('show')
        @confirm_entry.configure('show' => current == '*' ? '' : '*')
      end

      def update_strength
        level = Utils::PasswordGenerator.strength(@pw_entry.value)
        color = case level
                when :weak then COLORS[:red_err]
                when :medium then COLORS[:orange]
                else COLORS[:green_ok]
                end
        label = { weak: 'Débil', medium: 'Media', strong: 'Fuerte' }[level]
        @strength_label.configure(
          'text' => "  #{label}",
          'foreground' => color
        )
      end
    end
  end
end
