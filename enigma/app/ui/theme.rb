# frozen_string_literal: true

module Enigma
  module Theme
    COLORS = {
      bg_main: '#121212',
      bg_panel: '#242424',
      bg_input: '#1E1E1E',
      fg_primary: '#FFFFFF',
      fg_secondary: '#AAAAAA',
      orange: '#FF6600',
      orange_dim: '#CC5500',
      green_ok: '#00CC66',
      red_err: '#E04545',
      border: '#3A3A3A'
    }.freeze

    FONT = case RUBY_PLATFORM
           when /mingw|mswin|windows/i then '{Segoe UI}'
           when /darwin/ then '{Helvetica Neue}'
           else '{Helvetica}'
           end.freeze

    FONT_MONO = case RUBY_PLATFORM
                when /mingw|mswin|windows/i then 'Consolas'
                when /darwin/ then 'Menlo'
                else 'Courier'
                end.freeze

    FONT_EMOJI = case RUBY_PLATFORM
                 when /darwin/ then 'Apple Color Emoji'
                 when /mingw|mswin|windows/i then 'Segoe UI Emoji'
                 else 'Noto Color Emoji'
                 end.freeze

    def self.setup_ttk_styles!
      font9  = TkFont.new("#{FONT} 9")
      font10 = TkFont.new("#{FONT} 10")

      Tk::Tile::Style.configure('Treeview',
        'font' => font9,
        'background' => COLORS[:bg_input],
        'foreground' => COLORS[:fg_primary],
        'fieldbackground' => COLORS[:bg_input],
        'rowheight' => 22
      )
      Tk::Tile::Style.map('Treeview',
        'background' => ['selected', COLORS[:orange]],
        'foreground' => ['selected', COLORS[:fg_primary]]
      )
      Tk::Tile::Style.configure('Treeview.Heading',
        'font' => TkFont.new("#{FONT} 9 bold"),
        'background' => COLORS[:bg_panel],
        'foreground' => COLORS[:orange]
      )
      Tk::Tile::Style.configure('TButton',
        'font' => font9,
        'background' => COLORS[:bg_panel],
        'foreground' => COLORS[:fg_primary],
        'borderwidth' => 1
      )
      Tk::Tile::Style.configure('TCombobox',
        'fieldbackground' => COLORS[:bg_input],
        'foreground' => COLORS[:fg_primary],
        'font' => font10
      )
      Tk::Tile::Style.configure('TCombobox.Listbox',
        'background' => COLORS[:bg_input],
        'foreground' => COLORS[:fg_primary],
        'font' => font10
      )
    end
  end
end
