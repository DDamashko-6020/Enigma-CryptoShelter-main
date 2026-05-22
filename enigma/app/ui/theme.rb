# frozen_string_literal: true

module Enigma
  module Theme
    COLORS = {
      bg_main: '#0D0D0D',
      bg_panel: '#1A1A1A',
      bg_input: '#111111',
      fg_primary: '#E0E0E0',
      fg_secondary: '#666666',
      orange: '#FF6B00',
      orange_dim: '#CC4400',
      green_ok: '#00CC66',
      red_err: '#CC2200',
      border: '#2A2A2A'
    }.freeze

    FONT = 'Courier'

    FONT_EMOJI = case RUBY_PLATFORM
                 when /darwin/ then 'Apple Color Emoji'
                 when /mingw|mswin|windows/i then 'Segoe UI Emoji'
                 else 'Noto Color Emoji'
                 end.freeze
  end
end
