# frozen_string_literal: true

require 'tk'
require 'tkextlib/tile'
require 'tkextlib/tile/treeview'
require 'tkextlib/tile/tscrollbar'

module Enigma
  module UI
    class VaultPanel
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      MODE_EMPTY   = :empty
      MODE_VIEWING = :viewing
      MODE_EDITING = :editing
      MODE_NEW     = :new

      MODE_LABELS = {
        MODE_EMPTY   => 'No entry selected',
        MODE_VIEWING => nil,
        MODE_EDITING => nil,
        MODE_NEW     => 'Nueva entrada'
      }.freeze

      def initialize(parent, session)
        @frame   = TkFrame.new(parent) { background COLORS[:bg_main] }
        @manager = session[:manager]
        @selected = Core::Vault::NullCredential.new
        @mode = MODE_EMPTY
        @root = Tk.root
        build_ui
        after_build
      end

      def hide
        @frame.pack_forget
      end

      def show
        @frame.pack(side: :top, fill: :both, expand: true)
      end

      def update_session(new_session)
        @manager = new_session[:manager]
        @selected = Core::Vault::NullCredential.new
        @mode = MODE_EMPTY
        clear_form
        set_mode(MODE_EMPTY)
        refresh_list
      end

      private

      def build_ui
        build_toolbar(@frame)

        paned = TkPanedWindow.new(@frame) do
          orient 'horizontal'
          showhandle 0
          sashwidth 3
          background COLORS[:border]
        end
        paned.pack(fill: :both, expand: true)

        build_entry_list(paned)
        build_detail_form(paned)
        build_action_bar(@frame)
      end

      def after_build
        set_mode(MODE_EMPTY)
        refresh_list
      end

      # ─── TOOLBAR (top) ─────────────────────────────────

      def build_toolbar(parent)
        bar = TkFrame.new(parent) { background COLORS[:bg_panel] }
        bar.pack(fill: :x)

        @search_var = TkVariable.new
        search_entry = TkEntry.new(bar) do
          textvariable @search_var
          background COLORS[:bg_input]
          foreground COLORS[:fg_secondary]
          font TkFont.new("#{FONT} 9")
          insertbackground COLORS[:orange]
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
        end
        search_entry.pack(side: :left, fill: :x, expand: true, ipady: 2, padx: 4, pady: 4)
        search_entry.bind('KeyRelease') { on_search }

        @new_btn = TkLabel.new(bar) do
          text '  + Nueva entrada  '
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
          cursor 'hand2'
        end
        @new_btn.pack(side: :right, padx: [0, 4])
        @new_btn.bind('Button-1') { on_new }
      end

      # ─── ENTRY LIST (left) ──────────────────────────────

      def build_entry_list(parent)
        left = TkFrame.new(parent) { background COLORS[:bg_main] }
        parent.add(left)

        @tree = Tk::Tile::Treeview.new(left) do
          height 0
          selectmode 'browse'
          columns %w[site username]
          show 'headings'
        end

        @tree.heading_configure('site', text: 'Site')
        @tree.heading_configure('username', text: 'Username')

        @tree.columnconfigure('site', width: 160, minwidth: 100, anchor: 'w')
        @tree.columnconfigure('username', width: 130, minwidth: 80, anchor: 'w')

        scroll = Tk::Tile::Scrollbar.new(left) { orient 'vertical' }
        @tree.configure('yscrollcommand' => proc { |*a| scroll.set(*a) })
        scroll.command(proc { |*a| @tree.yview(*a) })

        @tree.pack(side: :left, fill: :both, expand: true, padx: [4, 0], pady: 4)
        scroll.pack(side: :right, fill: :y, pady: 4)

        @tree.bind('ButtonRelease-1') { on_tree_select }
        @tree.bind('KeyRelease-Up') { on_tree_select }
        @tree.bind('KeyRelease-Down') { on_tree_select }
      end

      # ─── DETAIL FORM (right) ────────────────────────────

      def build_detail_form(parent)
        right = TkFrame.new(parent) { background COLORS[:bg_main] }
        parent.add(right)

        @title_label = TkLabel.new(right) do
          text 'No entry selected'
          font TkFont.new("#{FONT} 14 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
          anchor 'w'
        end
        @title_label.pack(fill: :x, padx: 16, pady: [16, 8])

        sep = TkFrame.new(right) { background COLORS[:border]; height 1 }
        sep.pack(fill: :x, padx: 16, pady: [0, 12])

        build_field_row(right, 'SITE URL', :@site_var, :@site_entry)
        build_field_row(right, 'NOMBRE DE USUARIO', :@user_var, :@user_entry, copy_btn: true, copy_method: :on_copy_username)

        build_password_section(right)

        build_notes_section(right)

        build_timestamp_section(right)
      end

      def build_field_row(parent, label, var_ivar, entry_ivar, copy_btn: false, copy_method: nil)
        frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        frame.pack(fill: :x, padx: 16, pady: [4, 2])

        TkLabel.new(frame) do
          text label
          font TkFont.new("#{FONT} 8 bold")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end.pack(anchor: 'w')

        entry_frame = TkFrame.new(frame) { background COLORS[:bg_main] }
        entry_frame.pack(fill: :x)

        var = TkVariable.new
        instance_variable_set(var_ivar, var)

        entry = TkEntry.new(entry_frame) do
          textvariable var
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 10")
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          state 'disabled'
        end
        entry.pack(side: :left, fill: :x, expand: true, ipady: 2)
        instance_variable_set(entry_ivar, entry)

        return unless copy_btn && copy_method

        btn = TkLabel.new(entry_frame) do
          text '  Copiar usuario  '
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
          cursor 'hand2'
        end
        btn.pack(side: :right, padx: [6, 0])
        btn.bind('Button-1') { send(copy_method) }
        @copy_user_btn = btn
      end

      def build_password_section(parent)
        pw_frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        pw_frame.pack(fill: :x, padx: 16, pady: [4, 2])

        TkLabel.new(pw_frame) do
          text 'CONTRASENA'
          font TkFont.new("#{FONT} 8 bold")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end.pack(anchor: 'w')

        row = TkFrame.new(pw_frame) { background COLORS[:bg_main] }
        row.pack(fill: :x)

        @pass_var = TkVariable.new
        @pass_entry = TkEntry.new(row) do
          textvariable @pass_var
          show '*'
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 10")
          relief 'flat'
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          state 'disabled'
        end
        @pass_entry.pack(side: :left, fill: :x, expand: true, ipady: 2)
        @pass_entry.bind('KeyRelease') { update_strength_indicator(@pass_var.value) }

        toggle_btn = TkLabel.new(row) do
          text '  👁  '
          font TkFont.new(family: Theme::FONT_EMOJI, size: 10)
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
          cursor 'hand2'
        end
        toggle_btn.pack(side: :right, padx: [4, 0])
        toggle_btn.bind('Button-1') do
          current = @pass_entry.cget('show')
          @pass_entry.configure('show' => current == '*' ? '' : '*')
        end

        @gen_pass_btn = TkLabel.new(row) do
          text '  Generar  '
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:orange_dim]
          background COLORS[:bg_main]
          cursor 'hand2'
        end
        @gen_pass_btn.pack(side: :right, padx: [4, 0])
        @gen_pass_btn.bind('Button-1') { on_generate_password if @mode == MODE_EDITING || @mode == MODE_NEW }

        strength_frame = TkFrame.new(pw_frame) { background COLORS[:bg_main] }
        strength_frame.pack(fill: :x, pady: [2, 0])

        @strength_bar = TkFrame.new(strength_frame) do
          height 6
          background COLORS[:border]
        end
        @strength_bar.pack(fill: :x)

        @strength_fill = TkFrame.new(@strength_bar) do
          height 6
          background COLORS[:red_err]
        end
        @strength_fill.place(x: 0, y: 0, relwidth: 0, height: 6)

        @strength_label = TkLabel.new(strength_frame) do
          text ''
          font TkFont.new("#{FONT} 8")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end
        @strength_label.pack(anchor: 'w', pady: [2, 0])

        @copy_pass_btn = TkLabel.new(pw_frame) do
          text '  Copiar contrasena  '
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:orange_dim]
          background COLORS[:bg_main]
          cursor 'hand2'
        end
        @copy_pass_btn.pack(anchor: 'w', pady: [4, 0])
        @copy_pass_btn.bind('Button-1') { on_copy_password }
      end

      def build_notes_section(parent)
        notes_frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        notes_frame.pack(fill: :x, padx: 16, pady: [8, 2])

        TkLabel.new(notes_frame) do
          text 'NOTAS'
          font TkFont.new("#{FONT} 8 bold")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end.pack(anchor: 'w')

        @notes_text = TkText.new(notes_frame) do
          height 3
          width 30
          wrap 'word'
          background COLORS[:bg_input]
          foreground COLORS[:fg_primary]
          font TkFont.new("#{FONT} 10")
          highlightthickness 1
          highlightcolor COLORS[:orange]
          highlightbackground COLORS[:border]
          state 'disabled'
        end
        @notes_text.pack(fill: :x, pady: [2, 0])
      end

      def build_timestamp_section(parent)
        ts_frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        ts_frame.pack(fill: :x, padx: 16, pady: [8, 4])

        @created_label = TkLabel.new(ts_frame) do
          text ''
          font TkFont.new("#{FONT} 8")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end
        @created_label.pack(anchor: 'w')

        @updated_label = TkLabel.new(ts_frame) do
          text ''
          font TkFont.new("#{FONT} 8")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end
        @updated_label.pack(anchor: 'w')
      end

      # ─── ACTION BAR (bottom) ────────────────────────────

      def build_action_bar(parent)
        bar = TkFrame.new(parent) { background COLORS[:bg_panel] }
        bar.pack(fill: :x, pady: [4, 0])

        @flash_label = TkLabel.new(bar) do
          text ''
          font TkFont.new("#{FONT} 9 bold")
          foreground COLORS[:green_ok]
          background COLORS[:bg_panel]
        end
        @flash_label.pack(side: :left, padx: 12, pady: 6)

        btn_frame = TkFrame.new(bar) { background COLORS[:bg_panel] }
        btn_frame.pack(side: :right, padx: 8, pady: 6)

        colors = {
          edit:   COLORS[:orange],
          save:   COLORS[:green_ok],
          cancel: COLORS[:fg_secondary],
          delete: COLORS[:red_err]
        }
        methods_map = {
          edit:   :on_edit,
          save:   :on_save,
          cancel: :on_cancel,
          delete: :on_delete
        }
        labels = {
          edit:   '  Editar  ',
          save:   '  Guardar  ',
          cancel: '  Cancelar  ',
          delete: '  Eliminar  '
        }

        %i[edit save cancel delete].each do |key|
          btn = TkLabel.new(btn_frame) do
            text labels[key]
            font TkFont.new("#{FONT} 9 bold")
            foreground colors[key]
            background COLORS[:bg_panel]
            cursor 'hand2'
          end
          btn.pack(side: :left, padx: 2)
          btn.bind('Button-1') { send(methods_map[key]) }
          instance_variable_set("@#{key}_btn".to_sym, btn)
        end
      end

      # ─── STATE MACHINE ──────────────────────────────────

      def set_mode(mode)
        @mode = mode
        case mode
        when MODE_EMPTY
          @title_label.configure(text: 'No entry selected')
        when MODE_VIEWING
          @title_label.configure(text: @selected.site.to_s)
        when MODE_EDITING
          @title_label.configure(text: "Editando: #{@selected.site}")
        when MODE_NEW
          @title_label.configure(text: 'Nueva entrada')
        end
        update_form_state
        update_button_visuals
      end

      def update_form_state
        editable = @mode == MODE_EDITING || @mode == MODE_NEW
        state = editable ? 'normal' : 'disabled'
        [@site_entry, @user_entry, @pass_entry].each { |w| w.configure(state: state) if w }
        @notes_text.configure(state: state) if @notes_text
      end

      def update_button_visuals
        dim  = COLORS[:orange_dim]
        norm = COLORS[:orange]
        case @mode
        when MODE_EMPTY
          @new_btn.configure(foreground: COLORS[:orange])
          @edit_btn.configure(foreground: dim)
          @save_btn.configure(foreground: dim)
          @cancel_btn.configure(foreground: dim)
          @delete_btn.configure(foreground: dim)
          @copy_user_btn.configure(foreground: dim) if @copy_user_btn
          @copy_pass_btn.configure(foreground: dim) if @copy_pass_btn
          @gen_pass_btn.configure(foreground: dim) if @gen_pass_btn
        when MODE_VIEWING
          @new_btn.configure(foreground: COLORS[:orange])
          @edit_btn.configure(foreground: COLORS[:orange])
          @save_btn.configure(foreground: dim)
          @cancel_btn.configure(foreground: dim)
          @delete_btn.configure(foreground: COLORS[:red_err])
          @copy_user_btn.configure(foreground: COLORS[:orange]) if @copy_user_btn
          @copy_pass_btn.configure(foreground: COLORS[:orange]) if @copy_pass_btn
          @gen_pass_btn.configure(foreground: dim) if @gen_pass_btn
        when MODE_EDITING, MODE_NEW
          @new_btn.configure(foreground: dim)
          @edit_btn.configure(foreground: dim)
          @save_btn.configure(foreground: COLORS[:green_ok])
          @cancel_btn.configure(foreground: COLORS[:fg_secondary])
          @delete_btn.configure(foreground: dim)
          @copy_user_btn.configure(foreground: dim) if @copy_user_btn
          @copy_pass_btn.configure(foreground: dim) if @copy_pass_btn
          @gen_pass_btn.configure(foreground: COLORS[:orange]) if @gen_pass_btn
        end
      end

      # ─── TREE SELECTION ─────────────────────────────────

      def on_tree_select
        sel = @tree.selection
        return if sel.empty?

        cred = @manager.all.find { |c| c.id == sel.first }
        return unless cred

        @selected = cred
        load_credential_into_form(cred)
        set_mode(MODE_VIEWING)
      end

      def select_tree_item(id)
        @tree.selection.set(id)
      rescue StandardError
        nil
      end

      # ─── FORM LOAD / CLEAR ──────────────────────────────

      def load_credential_into_form(cred)
        @site_var.value    = cred.site
        @user_var.value    = cred.username
        @pass_var.value    = cred.password

        @notes_text.configure(state: 'normal')
        @notes_text.delete('1.0', 'end')
        @notes_text.insert('1.0', cred.notes)
        @notes_text.configure(state: @mode == MODE_EDITING || @mode == MODE_NEW ? 'normal' : 'disabled')

        @created_label.configure(text: "Creado: #{cred.created_at}") unless cred.created_at.to_s.empty?
        @updated_label.configure(text: "Actualizado: #{cred.updated_at}") unless cred.updated_at.to_s.empty?
        update_strength_indicator(cred.password)
      end

      def clear_form
        @site_var.value    = ''
        @user_var.value    = ''
        @pass_var.value    = ''

        @notes_text.configure(state: 'normal')
        @notes_text.delete('1.0', 'end')
        @notes_text.configure(state: 'disabled')

        @created_label.configure(text: '')
        @updated_label.configure(text: '')
        @strength_label.configure(text: '')
        @strength_fill.place(x: 0, y: 0, relwidth: 0, height: 6)
      end

      # ─── NEW ────────────────────────────────────────────

      def on_new
        @selected = Core::Vault::NullCredential.new
        clear_form
        set_mode(MODE_NEW)
        @site_entry.configure(state: 'normal')
        @site_entry.focus
      end

      # ─── EDIT ───────────────────────────────────────────

      def on_edit
        return if @mode != MODE_VIEWING
        return if @selected.null?

        set_mode(MODE_EDITING)
        @site_entry.focus
      end

      # ─── SAVE ───────────────────────────────────────────

      def on_save
        return unless @mode == MODE_EDITING || @mode == MODE_NEW
        return unless validate_form!

        site     = @site_var.value.strip
        username = @user_var.value.strip
        password = @pass_var.value
        notes    = @notes_text.get('1.0', 'end').strip

        begin
          if @mode == MODE_NEW
            cred = @manager.add(site: site, username: username, password: password, notes: notes)
            @selected = cred
          else
            cred = @manager.update(@selected.id,
              site: site, username: username, password: password, notes: notes)
            @selected = cred
          end

          refresh_list(@selected.id)
          load_credential_into_form(cred)
          set_mode(MODE_VIEWING)
          show_flash("Guardado: #{cred.site}")
        rescue ArgumentError, Errors::VaultError => e
          show_error(e.message)
        end
      end

      # ─── CANCEL ─────────────────────────────────────────

      def on_cancel
        return unless @mode == MODE_EDITING || @mode == MODE_NEW

        if @selected && !@selected.null?
          load_credential_into_form(@selected)
          set_mode(MODE_VIEWING)
          show_flash('Editado cancelado', color: COLORS[:fg_secondary])
        else
          clear_form
          set_mode(MODE_EMPTY)
        end
      end

      # ─── DELETE ─────────────────────────────────────────

      def on_delete
        return if @selected.null?
        return unless @mode == MODE_VIEWING

        confirmed = Tk.messageBox(
          'type' => 'yesno', 'icon' => 'warning',
          'title' => 'Confirmar eliminacion',
          'message' => "Eliminar '#{@selected.site}'?\nEsta accion no se puede deshacer."
        )
        return unless confirmed == 'yes'

        begin
          @manager.delete(@selected.id)
          @selected = Core::Vault::NullCredential.new
          clear_form
          refresh_list
          set_mode(MODE_EMPTY)
          show_flash('Eliminado', color: COLORS[:red_err])
        rescue Errors::CredentialNotFoundError => e
          show_error(e.message)
        end
      end

      # ─── COPY ───────────────────────────────────────────

      def on_copy_username
        return if @selected.null?

        copy_to_clipboard(@selected.username)
        show_flash('Usuario copiado, limpiando en 10s')
        start_clipboard_timer
      end

      def on_copy_password
        return if @selected.null?

        copy_to_clipboard(@selected.password)
        show_flash('Contrasena copiada, limpiando en 10s')
        start_clipboard_timer
      end

      def copy_to_clipboard(text)
        @root.clipboard_clear
        @root.clipboard_append(text)
      end

      def start_clipboard_timer
        @clipboard_timer&.cancel
        @clipboard_timer = TkAfter.new(10_000, 1) { clear_clipboard }
        @clipboard_timer.start
      end

      def clear_clipboard
        @root.clipboard_clear
      rescue StandardError
        nil
      end

      # ─── PASSWORD GENERATOR ─────────────────────────────

      def on_generate_password
        return unless @mode == MODE_EDITING || @mode == MODE_NEW

        pass = generate_random_password(20)
        @pass_var.value = pass
        @pass_entry.configure('show' => '')
        update_strength_indicator(pass)
      end

      def generate_random_password(length = 20)
        chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + %w[! @ # $ % ^ & * _ + = -]
        Array.new(length) { chars.sample }.join
      end

      def update_strength_indicator(password)
        score = 0
        score += 1 if password.length >= 8
        score += 1 if password.length >= 12
        score += 1 if password.length >= 16
        score += 1 if password =~ /[a-z]/
        score += 1 if password =~ /[A-Z]/
        score += 1 if password =~ /[0-9]/
        score += 1 if password =~ /[^a-zA-Z0-9]/

        if password.empty?
          @strength_label.configure(text: '')
          @strength_fill.place(x: 0, y: 0, relwidth: 0, height: 6)
        elsif score < 3
          rel_w = score.to_f / 7
          @strength_label.configure(text: 'Debil', foreground: COLORS[:red_err])
          @strength_fill.configure(background: COLORS[:red_err])
          @strength_fill.place(x: 0, y: 0, relwidth: rel_w, height: 6)
        elsif score < 5
          rel_w = score.to_f / 7
          @strength_label.configure(text: 'Media', foreground: COLORS[:orange])
          @strength_fill.configure(background: COLORS[:orange])
          @strength_fill.place(x: 0, y: 0, relwidth: rel_w, height: 6)
        else
          rel_w = score.to_f / 7
          @strength_label.configure(text: 'Fuerte', foreground: COLORS[:green_ok])
          @strength_fill.configure(background: COLORS[:green_ok])
          @strength_fill.place(x: 0, y: 0, relwidth: rel_w, height: 6)
        end
      end

      # ─── VALIDATION ─────────────────────────────────────

      def validate_form!
        if @site_var.value.strip.empty?
          show_error('El sitio no puede estar vacio')
          @site_entry.focus
          return false
        end
        if @user_var.value.strip.empty?
          show_error('El usuario no puede estar vacio')
          @user_entry.focus
          return false
        end
        if @pass_var.value.empty?
          show_error('La contrasena no puede estar vacia')
          @pass_entry.focus
          return false
        end
        true
      end

      # ─── SEARCH & LIST ──────────────────────────────────

      def on_search
        query = @search_var.value
        creds = query.strip.empty? ? @manager.all : @manager.find(query)
        populate_list(creds)
      end

      def refresh_list(select_id = nil)
        populate_list(filtered_credentials)
        return unless select_id

        select_tree_item(select_id)
      end

      def filtered_credentials
        @manager.all
      end

      def populate_list(credentials)
        @tree.delete(*@tree.children(''))
        credentials.each do |cred|
          @tree.insert('', 'end', id: cred.id,
                       values: [cred.site, cred.username])
        end
      end

      # ─── FLASH MESSAGES ─────────────────────────────────

      def show_flash(message, color: COLORS[:green_ok])
        @flash_label.configure(text: "  #{message}  ", foreground: color)
        TkAfter.new(3_000, 1) { @flash_label.configure(text: '') if @flash_label }
      end

      def show_error(message)
        show_flash(message, color: COLORS[:red_err])
      end
    end
  end
end
