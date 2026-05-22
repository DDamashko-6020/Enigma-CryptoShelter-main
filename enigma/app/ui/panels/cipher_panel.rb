# frozen_string_literal: true

require 'tk'
require 'tkextlib/tile'
require 'tkextlib/tile/tcombobox'
require 'tkextlib/tile/tscrollbar'

module Enigma
  module UI
    class CipherPanel
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(parent)
        @frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        @root  = Tk.root
        @key_visible = false
        build_layout
      end

      def hide
        @frame.pack_forget
      end

      def show
        @frame.pack(side: :top, fill: :both, expand: true)
      end

      private

      def build_layout
        body = TkFrame.new(@frame) { background COLORS[:bg_main] }
        body.pack(fill: :both, expand: true, padx: 20, pady: 20)

        build_left(body)
        build_right(body)
      end

      # ─── LEFT: CONFIGURATION ──────────────────────────────

      def build_left(parent)
        left = TkFrame.new(parent) { background COLORS[:bg_panel] }
        left.pack(side: :left, fill: :both, padx: [0, 8])

        cfg_label = TkLabel.new(left) do
          text '  CONFIGURATION'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end
        cfg_label.pack(anchor: 'w', padx: 16, pady: [16, 12])

        algo_label = TkLabel.new(left) do
          text '  ALGORITHM'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        algo_label.pack(anchor: 'w', padx: 16)

        @algorithm_var = TkVariable.new
        @algorithm_var.value = 'AES-256-GCM'
        algo_combo = Tk::Tile::Combobox.new(left) do
          textvariable @algorithm_var
          values Core::Facades::CipherFacade.available_algorithms
          state 'readonly'
        end
        algo_combo.pack(fill: :x, padx: 16, pady: [4, 12])

        key_label = TkLabel.new(left) do
          text '  ENCRYPTION KEY'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        key_label.pack(anchor: 'w', padx: 16)

        key_row = TkFrame.new(left) { background COLORS[:bg_panel] }
        key_row.pack(fill: :x, padx: 16, pady: [4, 16])

        @key_var = TkVariable.new
        @key_entry = TkEntry.new(key_row) do
          textvariable @key_var
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
        @key_entry.pack(side: :left, fill: :x, expand: true, ipady: 4)

        eye = TkLabel.new(key_row) do
          text '  👁  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 11)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        eye.pack(side: :left)
        eye.bind('Button-1') { toggle_key }

        btn_frame = TkFrame.new(left) { background COLORS[:bg_panel] }
        btn_frame.pack(fill: :x, padx: 16, pady: [0, 16])

        @encrypt_btn = TkButton.new(btn_frame) do
          text '  ENCRYPT  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:bg_main]
          background COLORS[:orange]
          relief 'flat'
          command -> { on_encrypt }
        end
        @encrypt_btn.pack(side: :left, padx: [0, 8], fill: :x, expand: true)

        @decrypt_btn = TkButton.new(btn_frame) do
          text '  DECRYPT  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          command -> { on_decrypt }
        end
        @decrypt_btn.pack(side: :left, fill: :x, expand: true)

        flash_card = TkFrame.new(left) { background COLORS[:bg_panel] }
        flash_card.pack(fill: :x, padx: 16, pady: [0, 16])

        @flash_label = TkLabel.new(flash_card) do
          text ''
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:green_ok]
          background COLORS[:bg_panel]
        end
        @flash_label.pack(anchor: 'w')
      end

      # ─── RIGHT: TEXT AREAS ────────────────────────────────

      def build_right(parent)
        right = TkFrame.new(parent) { background COLORS[:bg_panel] }
        right.pack(side: :left, fill: :both, expand: true, padx: [8, 0])

        input_label = TkLabel.new(right) do
          text '  INPUT'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        input_label.pack(anchor: 'w', padx: 16, pady: [16, 4])

        @char_count = TkLabel.new(right) do
          text '0 chars'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        @char_count.pack(anchor: 'e', padx: 16)

        input_frame = TkFrame.new(right) { background COLORS[:bg_panel] }
        input_frame.pack(fill: :x, padx: 16, pady: [0, 12])

        @input_text = TkText.new(input_frame) do
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 10")
          insertbackground COLORS[:orange]
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          height 6
          wrap 'word'
        end
        @input_text.pack(side: :left, fill: :both, expand: true)
        @input_text.bind('KeyRelease') { update_char_count }

        iscroll = Tk::Tile::Scrollbar.new(input_frame) { orient 'vertical' }
        iscroll.pack(side: :right, fill: :y)
        @input_text.configure('yscrollcommand' => proc { |*a| iscroll.set(*a) })
        iscroll.command(proc { |*a| @input_text.yview(*a) })

        output_label = TkLabel.new(right) do
          text '  OUTPUT'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        output_label.pack(anchor: 'w', padx: 16)

        output_frame = TkFrame.new(right) { background COLORS[:bg_panel] }
        output_frame.pack(fill: :x, padx: 16, pady: [4, 8])

        @output_text = TkText.new(output_frame) do
          background COLORS[:bg_input]
          foreground COLORS[:orange]
          font TkFont.new("#{FONT} 10")
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          height 6
          wrap 'word'
          state 'disabled'
        end
        @output_text.pack(side: :left, fill: :both, expand: true)

        oscroll = Tk::Tile::Scrollbar.new(output_frame) { orient 'vertical' }
        oscroll.pack(side: :right, fill: :y)
        @output_text.configure('yscrollcommand' => proc { |*a| oscroll.set(*a) })
        oscroll.command(proc { |*a| @output_text.yview(*a) })

        invert_btn = TkLabel.new(right) do
          text '  ⤮ INVERTIR  '
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
          cursor 'hand2'
          relief 'solid'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        invert_btn.pack(anchor: 'e', padx: 16, pady: [0, 16])
        invert_btn.bind('Button-1') { on_invert }
      end

      # ─── ENCRYPT ──────────────────────────────────────────

      def on_encrypt
        algorithm  = @algorithm_var.value
        key        = @key_var.value.strip
        plaintext  = @input_text.get('1.0', 'end').chomp

        if key.empty?
          show_error('Ingresa una clave')
          return
        end
        if plaintext.empty?
          show_error('Ingresa texto para cifrar')
          return
        end

        result = Core::Facades::CipherFacade.encrypt(algorithm, key, plaintext)
        set_output(result)
        show_flash('Texto cifrado')
      rescue Enigma::Errors::InvalidKeyError => e
        show_error(e.message)
      rescue => e
        show_error("Error: #{e.message}")
      end

      # ─── DECRYPT ──────────────────────────────────────────

      def on_decrypt
        algorithm   = @algorithm_var.value
        key         = @key_var.value.strip
        ciphertext  = @input_text.get('1.0', 'end').chomp

        if key.empty?
          show_error('Ingresa una clave')
          return
        end
        if ciphertext.empty?
          show_error('Ingresa texto para descifrar')
          return
        end

        result = Core::Facades::CipherFacade.decrypt(algorithm, key, ciphertext)
        set_output(result)
        show_flash('Texto descifrado')
      rescue Enigma::Errors::AuthTagError
        show_error('Clave incorrecta o texto manipulado')
      rescue Enigma::Errors::CipherError => e
        show_error(e.message)
      rescue => e
        show_error("Error: #{e.message}")
      end

      # ─── INVERT ───────────────────────────────────────────

      def on_invert
        input_content  = @input_text.get('1.0', 'end').chomp
        output_content = @output_text.get('1.0', 'end').chomp

        set_input(output_content)
        set_output(input_content)
      end

      # ─── HELPERS ──────────────────────────────────────────

      def set_output(text)
        @output_text.configure(state: 'normal')
        @output_text.delete('1.0', 'end')
        @output_text.insert('end', text)
        @output_text.configure(state: 'disabled')
      end

      def set_input(text)
        @input_text.delete('1.0', 'end')
        @input_text.insert('end', text)
      end

      def update_char_count
        len = @input_text.get('1.0', 'end').chomp.length
        @char_count.configure('text' => "#{len} chars")
      end

      def toggle_key
        @key_visible = !@key_visible
        @key_entry.configure('show' => @key_visible ? '' : '*')
      end

      def show_flash(message)
        @flash_label.configure('text' => "  #{message}  ", 'foreground' => COLORS[:green_ok])
        TkAfter.new(3_000, 1) { @flash_label.configure('text' => '') if @flash_label }
      end

      def show_error(message)
        @flash_label.configure('text' => "  #{message}  ", 'foreground' => COLORS[:red_err])
        TkAfter.new(4_000, 1) { @flash_label.configure('text' => '') if @flash_label }
      end
    end
  end
end
