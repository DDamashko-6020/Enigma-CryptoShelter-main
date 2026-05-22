# frozen_string_literal: true

#
# app/ui/main_window.rb
# Responsibility: TkRoot, session, startup flow, navigation, status bar.
#
# Pattern: Mediator (coordinates screens, panels, session)
#
#

require 'tk'
require 'tkextlib/tile'
require 'ostruct'

module Enigma
  module UI
    class MainWindow
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      require_relative 'screens/create_screen'
      require_relative 'screens/create_questions_screen'
      require_relative 'screens/unlock_screen'
      require_relative 'screens/recovery_screen'
      require_relative 'screens/change_password_screen'
      require_relative 'panels/vault_panel'
      require_relative 'panels/cipher_panel'
      require_relative 'panels/file_lock_panel'
      require_relative 'panels/user_panel'

      FONT_EMOJI = case RUBY_PLATFORM
                   when /darwin/ then 'Apple Color Emoji'
                   when /mingw|mswin|windows/i then 'Segoe UI Emoji'
                   else 'Noto Color Emoji'
                   end

      def initialize
        @root = TkRoot.new
        @root.title 'ENIGMA CRYPTOSHELTER'
        @root.background COLORS[:bg_main]
        @root.minsize(1200, 800)
        @root.geometry('1200x800+50+50')
        icon_path = File.join(__dir__, '..', '..', 'enigma_icon.ico')
        @root.iconbitmap(icon_path) if File.exist?(icon_path)
      end

      def run
        TkAfter.new(0, 1) { check_vault_on_startup }.start
        Tk.mainloop
      end

      private

      def check_vault_on_startup
        if Core::Vault::Storage.vault_exists?
          show_unlock_screen
        else
          show_create_screen
        end
      end

      SCREENS = {
        create_questions:  CreateQuestionsScreen,
        recovery:          RecoveryScreen,
        change_password:   ChangePasswordScreen
      }.freeze

      BACK_MAP = {
        create_questions: :show_create_screen,
        recovery:         :show_unlock_screen,
        change_password:  :show_recovery_screen
      }.freeze

      def show_screen(name, opts = {})
        @screen_frame&.destroy
        @screen_frame = TkFrame.new(@root) { background COLORS[:bg_main] }
        @screen_frame.pack(fill: :both, expand: true)

        back_action = BACK_MAP[name]
        klass = SCREENS[name]

        on_back = if back_action
                    if back_action.to_s.start_with?('show_')
                      -> { send(back_action) }
                    else
                      -> { show_screen(back_action) }
                    end
                  end

        @current_screen = klass.new(
          @screen_frame,
          **opts,
          on_back: on_back
        )
        Tk.update
      end

      def show_create_screen
        @screen_frame&.destroy
        @screen = CreateScreen.new(@root, method(:on_create_done))
      end

      def show_unlock_screen
        @screen_frame&.destroy
        @screen = UnlockScreen.new(@root, method(:on_vault_ready), method(:on_recovery))
      end

      def show_recovery_screen
        @screen_frame&.destroy
        Tk.update
        show_screen(:recovery, on_success: method(:on_recovery_success))
      end

      def on_create_done(session)
        @session = session
        @screen&.hide
        Tk.update
        show_screen(:create_questions, session: session,
                    on_success: method(:on_vault_ready))
      end

      def on_recovery
        @screen&.hide
        show_screen(:recovery, on_success: method(:on_recovery_success))
      end

      def on_recovery_success(recovered_keys)
        @screen_frame&.destroy
        Tk.update
        show_screen(:change_password, current_keys: recovered_keys,
                    on_success: method(:on_change_password_success))
      end

      def on_change_password_success(new_session)
        @session = new_session
        @screen_frame&.destroy
        Tk.update
        build_main_app
      end

      def on_vault_ready(session)
        @session = session
        @screen_frame&.destroy
        @screen&.hide rescue nil
        Tk.update
        build_main_app
      rescue StandardError => e
        warn "[on_vault_ready] #{e.class}: #{e.message}"
      end

      def on_logout
        @session[:manager].lock
        @session = nil
        @panels = {}
        @nav.destroy
        @top_sep.destroy
        @content.destroy
        @status_sep.destroy
        @status_bar.destroy
        Tk.update
        show_unlock_screen
      end

      def open_user_panel
        Panels::UserPanel.new(
          @root,
          session: @session,
          on_session_update: lambda { |new_session|
            @session = new_session
            update_vault_panel_session(new_session)
          }
        )
      end

      def update_vault_panel_session(new_session)
        return unless @panels&.key?('vault')

        @panels['vault'].update_session(new_session)
      end

      def build_main_app
        @root.geometry('1200x800+50+50')
        @root.resizable(false, false)
        @panels = {}
        @tab_order = {
          'vault' => 'Vault',
          'cipher_lab' => 'Cipher Lab',
          'file_lock' => 'File Lock'
        }.freeze
        build_content_area
        build_top_bar
        build_status_bar
        switch_tab('vault')
        Tk.update
      rescue StandardError => e
        warn "[build_main_app] #{e.class}: #{e.message}"
        TkLabel.new(@root) do
          text "Error: #{e.message}"
          foreground '#FF0000'
          background '#000000'
          font TkFont.new('Courier 12')
        end.pack
        Tk.update
      end

      def build_top_bar
        nav = TkFrame.new(@root) do
          background COLORS[:bg_main]
          highlightthickness 0
          height 40
        end
        nav.pack(side: :top, fill: :x)
        nav.pack_propagate(false)
        @nav = nav

        @top_sep = TkFrame.new(@root) do
          background COLORS[:orange]
          height 1
        end
        @top_sep.pack(side: :top, fill: :x)

        left = TkFrame.new(nav) { background COLORS[:bg_main] }
        left.pack(side: :left, fill: :y, padx: [20, 0])

        TkLabel.new(left) do
          text 'ENIGMA CRYPTOSHELTER'
          font TkFont.new("#{FONT} 12 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
        end.pack(side: :left)

        center = TkFrame.new(nav) { background COLORS[:bg_main] }
        center.pack(side: :left, expand: true)

        @tab_buttons = {}
        @tab_underlines = {}
        @tab_order.each do |key, display_name|
          f = TkFrame.new(center) { background COLORS[:bg_main] }
          f.pack(side: :left, padx: 15)

          btn = TkLabel.new(f) do
            text display_name
            font TkFont.new("#{FONT} 11")
            foreground COLORS[:fg_secondary]
            background COLORS[:bg_main]
            cursor 'hand2'
          end
          btn.pack(pady: [8, 0])

          underline = TkFrame.new(f) do
            background COLORS[:bg_main]
            height 2
          end
          underline.pack(fill: :x, pady: [4, 0])

          @tab_buttons[key] = btn
          @tab_underlines[key] = underline
          btn.bind('Button-1') { |_| switch_tab(key) }
        end

        @user_btn = TkLabel.new(nav) do
          text '  👤  '
          font TkFont.new(family: FONT_EMOJI, size: 12)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
          cursor 'hand2'
        end
        @user_btn.pack(side: :right)
        @user_btn.bind('Button-1') { open_user_panel }

        @logout_btn = TkLabel.new(nav) do
          text '  Cerrar Sesión  '
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
          cursor 'hand2'
        end
        @logout_btn.pack(side: :right)
        @logout_btn.bind('Button-1') { on_logout }

        @status_icon = TkLabel.new(nav) do
          text '  ● VAULT OPEN'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:green_ok]
          background COLORS[:bg_main]
        end
        @status_icon.pack(side: :right, padx: [0, 20])
      end

      def build_content_area
        @content = TkFrame.new(@root) { background COLORS[:bg_main] }
        @content.pack(side: :top, fill: :both, expand: true)
      end

      def build_status_bar
        @status_sep = TkFrame.new(@root) do
          background COLORS[:orange]
          height 1
        end
        @status_sep.pack(side: :bottom, fill: :x)

        @status_bar = TkFrame.new(@root) do
          background COLORS[:bg_main]
          height 30
        end
        @status_bar.pack(side: :bottom, fill: :x)
        @status_bar.pack_propagate(false)

        left = TkFrame.new(@status_bar) { background COLORS[:bg_main] }
        left.pack(side: :left, fill: :y, padx: [20, 0])

        TkLabel.new(left) do
          text '● OFFLINE MODE | AES-256-GCM ACTIVE'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end.pack(side: :left)

        right = TkFrame.new(@status_bar) { background COLORS[:bg_main] }
        right.pack(side: :right, fill: :y, padx: [0, 20])

        TkLabel.new(right) do
          text 'System Logs'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
          cursor 'hand2'
        end.pack(side: :left)

        TkLabel.new(right) do
          text ' | '
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end.pack(side: :left)

        TkLabel.new(right) do
          text 'Network Status'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
          cursor 'hand2'
        end.pack(side: :left)
      end

      def switch_tab(key)
        ensure_panel_created(key)
        return unless @panels.key?(key)

        @panels[@current_tab]&.hide if @current_tab && @current_tab != key
        @current_tab = key
        @tab_underlines.each do |k, underline|
          color = k == key ? COLORS[:orange] : COLORS[:bg_main]
          underline.configure('background' => color)
        end
        @tab_buttons.each do |k, btn|
          color = k == key ? COLORS[:fg_primary] : COLORS[:fg_secondary]
          btn.configure('foreground' => color)
        end
        @panels[key].show
      end

      def ensure_panel_created(key)
        return if @panels.key?(key)

        panel = case key
                when 'vault'
                  VaultPanel.new(@content, @session)
                when 'cipher_lab'
                  begin
                    CipherPanel.new(@content)
                  rescue StandardError => e
                    warn "Cipher Lab no disponible: #{e.message}"
                    nil
                  end
                when 'file_lock'
                  begin
                    FileLockPanel.new(@content, @session)
                  rescue StandardError => e
                    warn "File Lock no disponible: #{e.message}"
                    nil
                  end
                end
        @panels[key] = panel if panel
      end
    end
  end
end
