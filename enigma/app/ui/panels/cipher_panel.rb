# frozen_string_literal: true

#
# app/ui/panels/cipher_panel.rb
# Responsibility: Cipher Lab panel — encrypt/decrypt with multiple algorithms.
#

require 'tk'
require 'tkextlib/tile'
require 'tkextlib/tile/tcombobox'

module Enigma
  module UI
    class CipherPanel
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(parent)
        @frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        @root = Tk.root
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

        @algo_var = TkVariable.new
        @algo_var.value = 'AES-256-GCM'
        @algo_combo = Tk::Tile::Combobox.new(left) do
          textvariable @algo_var
          values Core::Facades::CipherFacade.available_algorithms
          state 'readonly'
        end
        @algo_combo.pack(fill: :x, padx: 16, pady: [4, 12])

        key_label = TkLabel.new(left) do
          text '  ENCRYPTION KEY'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        key_label.pack(anchor: 'w', padx: 16)

        key_row = TkFrame.new(left) { background COLORS[:bg_panel] }
        key_row.pack(fill: :x, padx: 16, pady: [4, 16])

        @key_entry = TkEntry.new(key_row) do
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

        panel = self
        @encrypt_btn = TkButton.new(btn_frame) do
          text '  ENCRYPT  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:bg_main]
          background COLORS[:orange]
          relief 'flat'
          command proc { panel.send(:on_encrypt) }
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
          command proc { panel.send(:on_decrypt) }
        end
        @decrypt_btn.pack(side: :left, fill: :x, expand: true)

        status_card = TkFrame.new(left) { background COLORS[:bg_panel] }
        status_card.pack(fill: :x, padx: 16, pady: [0, 16])

        @status_label = TkLabel.new(status_card) do
          text '  ●  SESSION ENCRYPTED'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:green_ok]
          background COLORS[:bg_panel]
        end
        @status_label.pack(anchor: 'w')
      end

      def build_right(parent)
        right = TkFrame.new(parent) { background COLORS[:bg_panel] }
        right.pack(side: :left, fill: :both, expand: true, padx: [8, 0])

        plain_label = TkLabel.new(right) do
          text '  PLAINTEXT'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        plain_label.pack(anchor: 'w', padx: 16, pady: [16, 4])

        @plain_chars = TkLabel.new(right) do
          text '0 chars'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        @plain_chars.pack(anchor: 'e', padx: 16)

        @plain_text = TkText.new(right) do
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
        @plain_text.pack(fill: :x, padx: 16, pady: [0, 12])
        @plain_text.bind('KeyRelease') { update_char_count }

        cipher_label = TkLabel.new(right) do
          text '  CIPHERTEXT'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        cipher_label.pack(anchor: 'w', padx: 16)

        @cipher_text = TkText.new(right) do
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
        @cipher_text.pack(fill: :x, padx: 16, pady: [4, 16])

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
        invert_btn.bind('Button-1') { swap_fields }
      end

      def on_encrypt
        algo = @algo_var.value
        key = @key_entry.value
        plain = @plain_text.get('1.0', 'end').strip

        if key.empty? || plain.empty?
          Tk.messageBox('type' => 'ok', 'icon' => 'warning',
                        'title' => 'Error', 'message' => 'Key and text required')
          return
        end

        @status_label.configure('text' => '  ●  ENCRYPTING...',
                                'foreground' => COLORS[:orange])
        @encrypt_btn.configure('state' => 'disabled')
        @decrypt_btn.configure('state' => 'disabled')
        @cipher_queue = Queue.new

        Thread.new do
          result = Core::Facades::CipherFacade.encrypt(algo, key, plain)
          @cipher_queue << [:ok, result, algo]
        rescue Errors::CipherError => e
          @cipher_queue << [:error, e.message]
        end

        poll_cipher_queue(:encrypt)
      end

      def on_decrypt
        algo = @algo_var.value
        key = @key_entry.value
        cipher = @cipher_text.get('1.0', 'end').strip

        if key.empty? || cipher.empty?
          Tk.messageBox('type' => 'ok', 'icon' => 'warning',
                        'title' => 'Error', 'message' => 'Key and ciphertext required')
          return
        end

        @status_label.configure('text' => '  ●  DECRYPTING...',
                                'foreground' => COLORS[:orange])
        @encrypt_btn.configure('state' => 'disabled')
        @decrypt_btn.configure('state' => 'disabled')
        @cipher_queue = Queue.new

        Thread.new do
          result = Core::Facades::CipherFacade.decrypt(algo, key, cipher)
          @cipher_queue << [:ok, result, algo]
        rescue Errors::CipherError => e
          @cipher_queue << [:error, e.message]
        end

        poll_cipher_queue(:decrypt)
      end

      def poll_cipher_queue(mode)
        result = begin
          @cipher_queue.pop(true)
        rescue ThreadError
          nil
        end

        if result.nil?
          TkAfter.new(100, 1) { poll_cipher_queue(mode) }.start
          return
        end

        @encrypt_btn.configure('state' => 'normal')
        @decrypt_btn.configure('state' => 'normal')

        case result[0]
        when :ok
          if mode == :encrypt
            set_ciphertext(result[1])
          else
            @plain_text.delete('1.0', 'end')
            @plain_text.insert('end', result[1])
            update_char_count
          end
          @status_label.configure(
            'text' => "  ●  #{mode == :encrypt ? 'ENCRYPTED' : 'DECRYPTED'} (#{result[2]})",
            'foreground' => COLORS[:green_ok]
          )
        when :error
          Tk.messageBox('type' => 'ok', 'icon' => 'error',
                        'title' => 'Error', 'message' => result[1])
        end
      end

      def toggle_key
        @key_visible = !@key_visible
        @key_entry.configure('show' => @key_visible ? '' : '*')
      end

      def update_char_count
        len = @plain_text.get('1.0', 'end').strip.length
        @plain_chars.configure('text' => "#{len} chars")
      end

      def set_ciphertext(text)
        @cipher_text.configure('state' => 'normal')
        @cipher_text.delete('1.0', 'end')
        @cipher_text.insert('end', text)
        @cipher_text.configure('state' => 'disabled')
      end

      def swap_fields
        plain = @plain_text.get('1.0', 'end').strip
        cipher = @cipher_text.get('1.0', 'end').strip

        @plain_text.delete('1.0', 'end')
        @plain_text.insert('end', cipher)
        update_char_count

        @cipher_text.configure('state' => 'normal')
        @cipher_text.delete('1.0', 'end')
        @cipher_text.insert('end', plain)
        @cipher_text.configure('state' => 'disabled')
      end
    end
  end
end
