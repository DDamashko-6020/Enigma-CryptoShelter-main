# frozen_string_literal: true

require 'tk'
require 'tkextlib/tile'
require 'tkextlib/tile/tcombobox'

module Enigma
  module UI
    class CreateQuestionsScreen
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      QUESTIONS = Core::Vault::Storage::SECURITY_QUESTIONS

      DEFAULT_QUESTIONS = [0, 7, 10].freeze

      def initialize(parent, session:, on_success:, on_back: nil)
        @parent     = parent
        @session    = session
        @on_success = on_success
        @on_back    = on_back
        build
      end

      def hide
        @frame.pack_forget
      end

      private

      def build
        @frame = TkFrame.new(@parent) { background COLORS[:bg_main] }
        @frame.pack(expand: true, fill: :both)

        canvas = TkFrame.new(@frame) { background COLORS[:bg_main] }
        canvas.pack(expand: true, pady: [20, 0])

        title = TkLabel.new(canvas) do
          text '🔒  PREGUNTAS DE SEGURIDAD'
          font TkFont.new("#{FONT} 14 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_main]
        end
        title.pack(pady: [0, 4])

        subtitle = TkLabel.new(canvas) do
          text 'Configura 3 preguntas para recuperar tu acceso'
          font TkFont.new("#{FONT} 10")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_main]
        end
        subtitle.pack(pady: [0, 16])

        build_question_fields(canvas)
        build_error_label(canvas)
        build_buttons(canvas)
      end

      def build_question_fields(parent)
        @q_vars    = []
        @a_entries = []

        DEFAULT_QUESTIONS.each_with_index do |q_idx, row|
          card = TkFrame.new(parent) { background COLORS[:bg_panel] }
          card.pack(fill: :x, padx: 40, pady: [0, 8])

          q_header = TkLabel.new(card) do
            text "  Pregunta #{row + 1}"
            font TkFont.new("#{FONT} 9 bold")
            foreground COLORS[:orange]
            background COLORS[:bg_panel]
          end
          q_header.pack(anchor: 'w', padx: 16, pady: [12, 0])

          q_var = TkVariable.new
          q_var.value = QUESTIONS[q_idx]
          q_combo = Tk::Tile::Combobox.new(card) do
            values QUESTIONS
            textvariable q_var
            state 'readonly'
          end
          q_combo.pack(fill: :x, padx: 16, pady: [4, 0])
          @q_vars << q_var

          a_label = TkLabel.new(card) do
            text '  Respuesta'
            font TkFont.new("#{FONT} 9")
            foreground COLORS[:fg_secondary]
            background COLORS[:bg_panel]
          end
          a_label.pack(anchor: 'w', padx: 16, pady: [8, 0])

          a_entry = TkEntry.new(card) do
            background COLORS[:bg_input]
            foreground COLORS[:fg_primary]
            font TkFont.new("#{FONT} 10")
            relief 'flat'
            highlightthickness 1
            highlightcolor COLORS[:orange]
            highlightbackground COLORS[:border]
          end
          a_entry.pack(fill: :x, padx: 16, pady: [2, 12], ipady: 2)
          @a_entries << a_entry
        end
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

      def build_buttons(parent)
        btn_frame = TkFrame.new(parent) { background COLORS[:bg_main] }
        btn_frame.pack(pady: [8, 20])

        if @on_back
          TkButton.new(btn_frame) do
            text '← VOLVER'
            background COLORS[:bg_main]
            foreground COLORS[:orange]
            relief 'flat'
            font TkFont.new("#{FONT} 10 bold")
            cursor 'hand2'
          end.tap do |b|
            b.command = -> { @on_back.call }
            b.pack(side: :left, padx: [0, 20])
          end
        end

        @continue_btn = TkButton.new(btn_frame) do
          text '  CONTINUAR  '
          font TkFont.new("#{FONT} 10 bold")
          foreground COLORS[:bg_main]
          background COLORS[:orange]
          relief 'flat'
        end
        @continue_btn.pack(fill: :x, padx: 40, ipady: 6)
        @continue_btn.command(proc { on_continue })
      end

      def on_continue
        selected_questions = @q_vars.map { |qv| qv.value.to_s.strip }
        answers = @a_entries.map { |e| e.value.to_s.strip }

        if selected_questions.uniq.size < 3
          show_error('Las 3 preguntas deben ser diferentes')
          return
        end

        if answers.any?(&:empty?)
          show_error('Todas las respuestas son obligatorias')
          return
        end

        questions = selected_questions.each_with_index.map do |q_text, i|
          idx = QUESTIONS.index(q_text)
          return show_error("Pregunta #{i + 1} no válida") unless idx
          { index: idx, answer: answers[i] }
        end
        vault_key = @session[:vault_key]

        @continue_btn.configure(text: '  Guardando...  ', state: 'disabled')
        @error_label.configure(text: '')

        @questions_queue = Queue.new

        Thread.new do
          cipher = Core::Cipher::AesGcm.new(vault_key)
          storage = Core::Vault::Storage.new(
            Core::Vault::Storage::VAULT_PATH, cipher
          )
          storage.update_security_questions!(questions, answers, vault_key)
          @questions_queue << [:ok, @session]
        rescue => e
          @questions_queue << [:error, e.message]
        end

        poll_questions_queue
      end

      def poll_questions_queue
        result = begin
          @questions_queue.pop(true)
        rescue ThreadError
          nil
        end

        if result.nil?
          TkAfter.new(100, 1) { poll_questions_queue }.start
          return
        end

        case result[0]
        when :ok
          @on_success.call(result[1])
        when :error
          show_error("Error: #{result[1]}")
          @continue_btn.configure(text: '  CONTINUAR  ', state: 'normal')
        end
      end

      def show_error(msg)
        @error_label.configure('text' => "  #{msg}", foreground: COLORS[:red_err])
      end
    end
  end
end
