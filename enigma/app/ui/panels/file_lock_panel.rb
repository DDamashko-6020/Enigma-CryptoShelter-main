# frozen_string_literal: true

#
# app/ui/panels/file_lock_panel.rb
# Responsibility: .ultra file encryption/decryption panel.
#

require 'tk'
require 'fileutils'

module Enigma
  module UI
    class FileLockPanel
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(parent, session)
        @frame     = TkFrame.new(parent) { background COLORS[:bg_main] }
        @session   = session
        @share_visible = false
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

        title = TkLabel.new(left) do
          text '  TERMINAL.FILE_ENCRYPTION'
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:fg_primary]
          background COLORS[:bg_panel]
        end
        title.pack(anchor: 'w', padx: 16, pady: [16, 0])

        subtitle = TkLabel.new(left) do
          text '  ACTIVE PROTOCOL: DOUBLE_LAYER_QUANTUM_SAFE'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        subtitle.pack(anchor: 'w', padx: 16, pady: [4, 16])

        build_drop_zone(left)
        build_share_key(left)
        build_action_buttons(left)
      end

      def build_drop_zone(parent)
        drop = TkFrame.new(parent) do
          background COLORS[:bg_input]
          highlightthickness 2
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        drop.pack(fill: :x, padx: 16, pady: [0, 12], ipady: 20)

        icon = TkLabel.new(drop) do
          text '📄'
          font TkFont.new(family: Theme::FONT_EMOJI, size: 14)
          foreground COLORS[:orange]
          background COLORS[:bg_input]
        end
        icon.pack(pady: [8, 0])

        browse = TkLabel.new(drop) do
          text 'DROP FILE OR BROWSE'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        browse.pack(pady: [4, 8])
        browse.bind('Button-1') { on_browse }

        @file_label = TkLabel.new(drop) do
          text ''
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:orange]
          background COLORS[:bg_input]
        end
        @file_label.pack
      end

      def build_share_key(parent)
        share_label = TkLabel.new(parent) do
          text '  SHARE KEY (LAYER 2)'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        share_label.pack(anchor: 'w', padx: 16)

        share_row = TkFrame.new(parent) { background COLORS[:bg_panel] }
        share_row.pack(fill: :x, padx: 16, pady: [4, 16])

        @share_entry = TkEntry.new(share_row) do
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
        @share_entry.pack(side: :left, fill: :x, expand: true, ipady: 4)

        eye = TkLabel.new(share_row) do
          text '  👁  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 11)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        eye.pack(side: :left)
        eye.bind('Button-1') { toggle_share }
      end

      def build_action_buttons(parent)
        btn_frame = TkFrame.new(parent) { background COLORS[:bg_panel] }
        btn_frame.pack(fill: :x, padx: 16, pady: [0, 16])

        me = self
        @lock_btn = TkButton.new(btn_frame) do
          text '  🔒 LOCK FILE → .ultra  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:bg_main]
          background COLORS[:orange]
          relief 'flat'
          command proc { me.send(:on_lock) }
        end
        @lock_btn.pack(fill: :x, pady: [0, 8])

        @unlock_btn = TkButton.new(btn_frame) do
          text '  🔓 UNLOCK .ultra  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          command proc { me.send(:on_unlock) }
        end
        @unlock_btn.pack(fill: :x)
      end

      def build_right(parent)
        right = TkFrame.new(parent) { background COLORS[:bg_panel] }
        right.pack(side: :left, fill: :both, expand: true, padx: [8, 0])

        matrix = TkLabel.new(right) do
          text '  ENCRYPTION MATRIX'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end
        matrix.pack(anchor: 'w', padx: 16, pady: [16, 12])

        layers = TkFrame.new(right) { background COLORS[:bg_panel] }
        layers.pack(fill: :x, padx: 16, pady: [0, 16])

        layer1 = TkLabel.new(layers) do
          text '  Layer 1: AES-256-GCM (master key)'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_primary]
          background COLORS[:bg_panel]
        end
        layer1.pack(anchor: 'w', pady: [0, 2])

        arrow = TkLabel.new(layers) do
          text '  ↓'
          font TkFont.new("#{FONT} 11")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end
        arrow.pack(anchor: 'w', pady: [0, 2])

        layer2 = TkLabel.new(layers) do
          text '  Layer 2: ChaCha20-Poly1305 (share key)'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_primary]
          background COLORS[:bg_panel]
        end
        layer2.pack(anchor: 'w', pady: [0, 12])

        output_label = TkLabel.new(right) do
          text '  TERMINAL OUTPUT'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        output_label.pack(anchor: 'w', padx: 16)

        @output_path = TkEntry.new(right) do
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 10")
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        @output_path.pack(fill: :x, padx: 16, pady: [4, 16])

        @status_label = TkLabel.new(right) do
          text '  ●  LOCAL SESSION ENCRYPTED'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:green_ok]
          background COLORS[:bg_panel]
        end
        @status_label.pack(anchor: 'w', padx: 16, pady: [0, 16])

        @flash_label = TkLabel.new(right) do
          text ''
          font TkFont.new("#{FONT} 9 bold")
          background COLORS[:bg_panel]
        end
        @flash_label.pack(anchor: 'w', padx: 16)
      end

      def on_browse
        file = Tk.getOpenFile
        return if file.nil? || file.empty?

        @selected_path = file
        @file_label.configure('text' => File.basename(file))
      end

      def on_lock
        path = @selected_path
        share = @share_entry.value

        unless path && File.exist?(path)
          Tk.messageBox('type' => 'ok', 'icon' => 'warning',
                        'title' => 'Error', 'message' => 'Select a file first')
          return
        end

        if share.empty?
          Tk.messageBox('type' => 'ok', 'icon' => 'warning',
                        'title' => 'Error', 'message' => 'Enter a share key')
          return
        end

        return if @processing

        @processing = true
        set_processing(true)

        filelock_key = @session[:filelock_key]
        facade = Core::Facades::FileLockFacade.new
        @lock_queue = Queue.new

        Thread.new do
          facade.lock(path, filelock_key, share)
          @lock_queue << [:ok, "#{path}.ultra"]
        rescue StandardError => e
          @lock_queue << [:error, e.message]
        end

        poll_lock_queue
      end

      def on_unlock
        path = @selected_path
        share = @share_entry.value

        unless path && File.exist?(path)
          Tk.messageBox('type' => 'ok', 'icon' => 'warning',
                        'title' => 'Error', 'message' => 'Select a .ultra file')
          return
        end

        unless path.end_with?('.ultra')
          Tk.messageBox('type' => 'ok', 'icon' => 'warning',
                        'title' => 'Error', 'message' => 'File must have .ultra extension')
          return
        end

        if share.empty?
          Tk.messageBox('type' => 'ok', 'icon' => 'warning',
                        'title' => 'Error', 'message' => 'Enter the share key')
          return
        end

        return if @processing

        @processing = true
        set_processing(true)

        filelock_key = @session[:filelock_key]
        facade = Core::Facades::FileLockFacade.new
        @lock_queue = Queue.new

        Thread.new do
          facade.unlock(path, filelock_key, share)
          @lock_queue << [:ok, path.delete_suffix('.ultra')]
        rescue Errors::AuthTagError
          @lock_queue << [:error, 'Wrong master password or share key']
        rescue StandardError => e
          @lock_queue << [:error, e.message]
        end

        poll_lock_queue
      end

      def poll_lock_queue
        result = begin
          @lock_queue.pop(true)
        rescue ThreadError
          nil
        end

        if result.nil?
          TkAfter.new(100, 1) { poll_lock_queue }.start
          return
        end

        @processing = false
        set_processing(false)

        case result[0]
        when :ok
          @output_path.delete(0, 'end')
          @output_path.insert(0, result[1].to_s)
          @status_label.configure(
            'text' => '  ●  OPERATION COMPLETE',
            'foreground' => COLORS[:green_ok]
          )
        when :error
          Tk.messageBox('type' => 'ok', 'icon' => 'error',
                        'title' => 'Error', 'message' => result[1])
        end
      end

      def set_processing(active)
        if active
          @lock_btn.configure('state' => 'disabled',
                              'text' => '  ⏳ PROCESSING...  ')
          @unlock_btn.configure('state' => 'disabled')
          @status_label.configure(
            'text' => '  ●  PROCESSING...',
            'foreground' => COLORS[:orange]
          )
        else
          @lock_btn.configure('state' => 'normal',
                              'text' => '  🔒 LOCK FILE → .ultra  ')
          @unlock_btn.configure('state' => 'normal')
        end
      end

      def toggle_share
        @share_visible = !@share_visible
        @share_entry.configure('show' => @share_visible ? '' : '*')
      end
    end
  end
end
