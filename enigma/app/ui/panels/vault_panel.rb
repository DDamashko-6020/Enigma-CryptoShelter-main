# frozen_string_literal: true

#
# app/ui/panels/vault_panel.rb
# Responsibility: KeePass-style vault panel with credential list + form.
#

require 'tk'
require 'tkextlib/tile'
require 'tkextlib/tile/treeview'
require 'tkextlib/tile/tscrollbar'

module Enigma
  module UI
    class VaultPanel
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(parent, session)
        @frame   = TkFrame.new(parent) { background COLORS[:bg_main] }
        @manager = session[:manager]
        @selected_credential = Core::Vault::NullCredential.new
        @clipboard_timer = nil
        build_ui
        refresh_list
      end

      def hide
        @frame.pack_forget
      end

      def show
        @frame.pack(side: :top, fill: :both, expand: true)
      end

      def update_session(new_session)
        @manager = new_session[:manager]
        refresh_list
      end

      private

      def build_ui
        body = TkFrame.new(@frame) { background COLORS[:bg_main] }
        body.pack(fill: :both, expand: true)

        build_sidebar(body)
        build_form_panel(body)
      end

      def build_sidebar(parent)
        left = TkFrame.new(parent) { background COLORS[:bg_main] }
        left.pack(side: :left, fill: :both, padx: [12, 4], pady: [12, 12])

        search_frame = TkFrame.new(left) { background COLORS[:bg_input] }
        search_frame.pack(fill: :x)

        @search_var = TkVariable.new
        search_entry = TkEntry.new(search_frame) do
          textvariable @search_var
          background COLORS[:bg_input]
          foreground COLORS[:fg_secondary]
          font TkFont.new("#{FONT} 11")
          insertbackground COLORS[:orange]
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        search_entry.pack(fill: :x, ipady: 6, padx: 4, pady: 4)
        search_entry.insert(0, '🔍 BUSCAR...')

        search_entry.bind('FocusIn') do
          next unless @search_var.value == '🔍 BUSCAR...'

          @search_var.value = ''
          search_entry.configure('foreground' => COLORS[:fg_primary])
        end
        search_entry.bind('FocusOut') do
          next unless @search_var.value.empty?

          @search_var.value = '🔍 BUSCAR...'
          search_entry.configure('foreground' => COLORS[:fg_secondary])
        end
        search_entry.bind('KeyRelease') { on_search }

        list_frame = TkFrame.new(left) { background COLORS[:bg_main] }
        list_frame.pack(fill: :both, expand: true, pady: [8, 0])

        @tree = Tk::Tile::Treeview.new(list_frame) do
          height 0
          selectmode 'browse'
          columns %w[site username]
        end
        @tree.columnconfigure('#0', width: 0, minwidth: 0, stretch: false)
        @tree.columnconfigure('site', width: 200, minwidth: 140)
        @tree.columnconfigure('username', width: 100, minwidth: 60)

        scroll = Tk::Tile::Scrollbar.new(list_frame) { orient 'vertical' }
        @tree.configure('yscrollcommand' => proc { |*a| scroll.set(*a) })
        scroll.command(proc { |*a| @tree.yview(*a) })

        @tree.pack(side: :left, fill: :both, expand: true)
        scroll.pack(side: :right, fill: :y)
        @tree.bind('ButtonRelease-1') { on_item_selected }

        new_btn = TkLabel.new(left) do
          text '  + NUEVA ENTRADA'
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
          cursor 'hand2'
          relief 'solid'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        new_btn.pack(fill: :x, pady: [8, 0])
        new_btn.bind('Button-1') { on_new_credential }
      end

      def build_form_panel(parent)
        right = TkFrame.new(parent) { background COLORS[:bg_panel] }
        right.pack(side: :left, fill: :both, expand: true, padx: [4, 12], pady: [12, 12])

        @site_var   = TkVariable.new
        @user_var   = TkVariable.new
        @pass_var   = TkVariable.new

        build_header(right)
        build_field(right, 'SITE URL', @site_var)
        build_field(right, 'USERNAME', @user_var)
        build_password_field(right)
        build_notes_field(right)
        build_action_bar(right)
      end

      def build_header(parent)
        meta = TkLabel.new(parent) do
          text 'CREDENTIAL METADATA'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        meta.pack(anchor: 'w', padx: 16, pady: [16, 0])

        @title_label = TkLabel.new(parent) do
          text ''
          font TkFont.new("#{FONT} 12 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end
        @title_label.pack(anchor: 'w', padx: 16, pady: [2, 4])

        @meta_label = TkLabel.new(parent) do
          text ''
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        @meta_label.pack(anchor: 'w', padx: 16, pady: [0, 8])
      end

      def build_field(parent, label, variable)
        row = TkFrame.new(parent) { background COLORS[:bg_panel] }
        row.pack(fill: :x, padx: 16, pady: [8, 0])

        lbl = TkLabel.new(row) do
          text "  #{label}"
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        lbl.pack(anchor: 'w')

        entry = TkEntry.new(row) do
          textvariable variable
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 11")
          insertbackground COLORS[:orange]
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        entry.pack(fill: :x, ipady: 4, pady: [2, 0])
      end

      def build_password_field(parent)
        row = TkFrame.new(parent) { background COLORS[:bg_panel] }
        row.pack(fill: :x, padx: 16, pady: [8, 0])

        lbl = TkLabel.new(row) do
          text '  PASSWORD'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        lbl.pack(anchor: 'w')

        pass_row = TkFrame.new(row) { background COLORS[:bg_panel] }
        pass_row.pack(fill: :x, pady: [2, 0])

        @pass_entry = TkEntry.new(pass_row) do
          textvariable @pass_var
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 11")
          insertbackground COLORS[:orange]
          relief 'flat'
          show '*'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        @pass_entry.pack(side: :left, fill: :x, expand: true, ipady: 4)

        toggle_btn = TkLabel.new(pass_row) do
          text '  👁  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 11)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        toggle_btn.pack(side: :left)
        toggle_btn.bind('Button-1') { toggle_password }

        gen_btn = TkLabel.new(pass_row) do
          text '  ⚡  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 11)
          foreground COLORS[:orange]
          background COLORS[:bg_input]
          cursor 'hand2'
        end
        gen_btn.pack(side: :left)
        gen_btn.bind('Button-1') { on_generate }

        @strength_label = TkLabel.new(row) do
          text ''
          font TkFont.new("#{FONT} 9")
          background COLORS[:bg_panel]
        end
        @strength_label.pack(anchor: 'w', pady: [2, 0])
      end

      def build_notes_field(parent)
        row = TkFrame.new(parent) { background COLORS[:bg_panel] }
        row.pack(fill: :x, padx: 16, pady: [8, 0])

        lbl = TkLabel.new(row) do
          text '  NOTAS'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end
        lbl.pack(anchor: 'w')

        @notes_text = TkText.new(row) do
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 10")
          insertbackground COLORS[:orange]
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          height 4
          wrap 'word'
        end
        @notes_text.pack(fill: :x, pady: [2, 0])
      end

      def build_action_bar(parent)
        sep = TkFrame.new(parent) do
          background COLORS[:border]
          height 1
        end
        sep.pack(fill: :x, padx: 16, pady: [12, 0])

        @flash_label = TkLabel.new(parent) do
          text ''
          font TkFont.new("#{FONT} 9 bold")
          background COLORS[:bg_panel]
        end
        @flash_label.pack(anchor: 'w', padx: 16, pady: [4, 0])

        row = TkFrame.new(parent) { background COLORS[:bg_panel] }
        row.pack(fill: :x, padx: 16, pady: [8, 16])

        panel = self
        buttons = [
          ['  💾 GUARDAR', :on_save, COLORS[:orange], COLORS[:bg_main]],
          ['  🗑 ELIMINAR', :on_delete, COLORS[:red_err], COLORS[:bg_main]],
          ['  📋 COPIAR CLAVE', :on_copy, COLORS[:orange], COLORS[:bg_main]]
        ]
        buttons.each do |text, method, fg, bg|
          btn = TkLabel.new(row) do
            text text
            font TkFont.new("#{FONT} 9 bold")
            foreground fg
            background bg
            cursor 'hand2'
            relief 'solid'
            highlightthickness 1
            highlightcolor fg
            highlightbackground COLORS[:border]
          end
          btn.pack(side: :left, padx: [0, 8])
          btn.bind('Button-1', proc { panel.send(method) })
        end
      end

      def on_search
        query = @search_var.value
        return if query == '🔍 BUSCAR...' || query.nil?

        if query.strip.empty?
          populate_list(@manager.all)
        else
          populate_list(@manager.find(query))
        end
      end

      def on_item_selected
        sel = @tree.selection
        return if sel.empty?

        cred = @manager.all.find { |c| c.id == sel[0] }
        return unless cred

        load_credential(cred)
      end

      def on_new_credential
        @selected_credential = Core::Vault::NullCredential.new
        clear_form
        auto_generate_password
      end

      def raw_password
        @pass_var.value.gsub('-', '')
      end

      def on_save
        notes = @notes_text.get('1.0', 'end').strip
        if @selected_credential.null?
          cred = @manager.add(
            site: @site_var.value.strip,
            username: @user_var.value.strip,
            password: raw_password,
            notes: notes
          )
          @selected_credential = cred
        else
          @selected_credential = @manager.update(
            @selected_credential.id,
            site: @site_var.value.strip,
            username: @user_var.value.strip,
            password: raw_password,
            notes: notes
          )
        end
        refresh_list
        flash('✓ Guardado', COLORS[:green_ok])
      rescue ArgumentError, Errors::VaultError => e
        flash("Error: #{e.message}", COLORS[:red_err])
      end

      def on_delete
        return if @selected_credential.null?

        confirmed = Tk.messageBox(
          'type' => 'yesno', 'icon' => 'warning',
          'title' => 'Confirmar',
          'message' => "¿Eliminar '#{@selected_credential.site}'?"
        )
        return unless confirmed == 'yes'

        @manager.delete(@selected_credential.id)
        @selected_credential = Core::Vault::NullCredential.new
        clear_form
        refresh_list
        flash('✓ Eliminado', COLORS[:green_ok])
      rescue Errors::CredentialNotFoundError => e
        flash("Error: #{e.message}", COLORS[:red_err])
      end

      def on_copy
        return if @selected_credential.null?

        TkClipboard.clear
        TkClipboard.add(@selected_credential.password)
        flash('✓ Copiado — limpiando en 10s', COLORS[:green_ok])
        @clipboard_timer&.cancel
        @clipboard_timer = TkAfter.new(10_000, 1) { TkClipboard.clear }
        @clipboard_timer.start
      end

      def auto_generate_password
        pass = Utils::PasswordGenerator.generate(length: 20, symbols: true)
        @pass_var.value = Utils::PasswordGenerator.format(pass)
        update_strength(pass)
        @pass_entry.configure('show' => '')
      end

      def on_generate
        auto_generate_password
      end

      def toggle_password
        current = @pass_entry.cget('show')
        @pass_entry.configure('show' => current == '*' ? '' : '*')
      end

      def update_strength(password)
        level = Utils::PasswordGenerator.strength(password)
        color = case level
                when :weak then COLORS[:red_err]
                when :medium then COLORS[:orange]
                else COLORS[:green_ok]
                end
        label = { weak: 'Débil', medium: 'Media', strong: 'Fuerte' }[level]
        @strength_label.configure('text' => "  #{label}", 'foreground' => color)
      end

      def refresh_list
        populate_list(@manager.all)
      end

      def populate_list(credentials)
        @tree.delete(*@tree.children(''))
        batch = []
        credentials.each do |cred|
          batch << [cred.id, cred.site, cred.username]
          next unless batch.size >= 100

          batch.each { |id, site, user| @tree.insert('', 'end', id: id, values: [site, user]) }
          batch.clear
          Tk.update
        end
        batch.each { |id, site, user| @tree.insert('', 'end', id: id, values: [site, user]) }
        Tk.update
      end

      def clear_form
        @site_var.value = ''
        @user_var.value = ''
        @pass_var.value = ''
        @notes_text.delete('1.0', 'end')
        @strength_label.configure('text' => '')
        @meta_label.configure('text' => '')
        @title_label.configure('text' => '')
      end

      def load_credential(cred)
        @selected_credential = cred
        @site_var.value   = cred.site
        @user_var.value   = cred.username
        @pass_var.value   = Utils::PasswordGenerator.format(cred.password)
        @notes_text.delete('1.0', 'end')
        @notes_text.insert('end', cred.notes)
        update_strength(cred.password)
        @title_label.configure('text' => cred.site)
        @meta_label.configure(
          'text' => "Actualizado: #{cred.updated_at}"
        )
      end

      def flash(message, color)
        @flash_label.configure('text' => message, 'foreground' => color)
        TkAfter.new(2_000, 1) { @flash_label.configure('text' => '') }.start
      end
    end
  end
end
