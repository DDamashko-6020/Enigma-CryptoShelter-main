#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tk'
require 'tkextlib/tile'
require 'ostruct'

# Tk 0.6.0 + Ruby 3.x frozen_string_literal compatibility
class TclTkIp
  # rubocop:disable Naming/MethodName
  alias _toUTF8_original _toUTF8
  def _toUTF8(str, enc = nil)
    str = str.dup if str.frozen?
    _toUTF8_original(str, enc)
  end
  # rubocop:enable Naming/MethodName
end

require_relative 'app/core/core'
require_relative 'utils/password_generator'
require_relative 'utils/validator'
require_relative 'utils/file_handler'
require_relative 'app/ui/theme'
require_relative 'app/ui/main_window'

Enigma::UI::MainWindow.new.run
