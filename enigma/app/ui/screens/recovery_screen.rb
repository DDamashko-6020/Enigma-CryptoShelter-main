# frozen_string_literal: true

#
# app/ui/screens/recovery_screen.rb
# Responsibility: Password recovery via security questions from vault header.
# Falls back to auth.dat for vaults created before the header format update.
# On success → calls on_success with recovered vault_key.
#

require 'tk'

module Enigma
  module UI
    class RecoveryScreen
      COLORS = Theme::COLORS
      FONT   = Theme::FONT

      def initialize(parent, on_success:, on_back: nil)
        @parent     = parent
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

        card = TkFrame.new(@frame) { background COLORS[:bg_panel] }
        card.place(relx: 0.5, rely: 0.5, anchor: 'center')

        TkLabel.new(card) do
          text '🔓  RECUPERAR ACCESO'
          font TkFont.new("#{FONT} 14 bold")
          foreground COLORS[:orange]
          background COLORS[:bg_panel]
        end.pack(pady: [20, 4])

        TkLabel.new(card) do
          text 'Responde las preguntas de seguridad configuradas'
          font TkFont.new("#{FONT} 10")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
        end.pack(pady: [0, 16])

        @answer_entries = []

        questions = Core::Vault::Storage.read_question_texts
        if questions.nil? || questions.empty?
          TkLabel.new(card) do
            text '  No hay preguntas de seguridad configuradas.'
            font TkFont.new("#{FONT} 9")
            foreground COLORS[:red_err]
            background COLORS[:bg_panel]
          end.pack(pady: 20)
        else
          questions.each_with_index do |q, i|
            next if q.nil? || q.empty?

            q_frame = TkFrame.new(card) { background COLORS[:bg_panel] }
            q_frame.pack(fill: :x, padx: 30, pady: [0, 10])

            TkLabel.new(q_frame) do
              text "  #{i + 1}. #{q}"
              font TkFont.new("#{FONT} 9 bold")
              foreground COLORS[:orange]
              background COLORS[:bg_panel]
              wraplength 380
              justify 'left'
            end.pack(anchor: 'w', padx: 16, pady: [12, 4])

            entry = TkEntry.new(q_frame) do
              background COLORS[:bg_input]
              foreground COLORS[:fg_primary]
              font TkFont.new("#{FONT} 11")
              relief 'flat'
              highlightthickness 1
              highlightcolor COLORS[:orange]
              highlightbackground COLORS[:border]
            end
            entry.pack(fill: :x, padx: 16, pady: [0, 12], ipady: 4)
            @answer_entries << entry
          end

          btn_frame = TkFrame.new(card) { background COLORS[:bg_panel] }
          btn_frame.pack(pady: [8, 4])

          @verify_btn = TkButton.new(btn_frame) do
            text '  VERIFICAR RESPUESTAS  '
            font TkFont.new("#{FONT} 10 bold")
            foreground COLORS[:bg_main]
            background COLORS[:orange]
            relief 'flat'
          end
          @verify_btn.pack(fill: :x, padx: 40, ipady: 6)
          @verify_btn.command = -> { on_verify }
        end

        @error_label = TkLabel.new(card) do
          text ''
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:red_err]
          background COLORS[:bg_panel]
        end
        @error_label.pack(anchor: 'w', padx: 30, pady: [4, 0])

        return unless @on_back

        TkLabel.new(card) do
          text '  ← Volver a la pantalla de inicio'
          font TkFont.new("#{FONT} 9")
          foreground COLORS[:fg_secondary]
          background COLORS[:bg_panel]
          cursor 'hand2'
        end.tap do |l|
          l.pack(pady: [4, 12])
          l.bind('Button-1') { hide; @on_back.call }
        end
      end

      def on_verify
        answers = @answer_entries.map(&:value)

        if answers.any?(&:empty?)
          @error_label.configure(text: 'Responde todas las preguntas')
          return
        end

        @verify_btn.configure(text: 'Verificando...', state: 'disabled')
        @error_label.configure(text: '')
        @verify_btn.update

        Thread.new do
          begin
            unless Core::Vault::Storage.verify_answers(answers)
              TkAfter.new(0, 1) do
                @error_label.configure(text: 'Respuestas incorrectas', foreground: COLORS[:red_err])
                @verify_btn.configure(text: '  VERIFICAR RESPUESTAS  ', state: 'normal')
                clear_answer_fields
              end.start
              next
            end

            recovered = Core::Vault::Storage.read_recovery_data(nil, answers)
            unless recovered
              TkAfter.new(0, 1) do
                @error_label.configure(text: 'Error al recuperar clave', foreground: COLORS[:red_err])
                @verify_btn.configure(text: '  VERIFICAR RESPUESTAS  ', state: 'normal')
              end.start
              next
            end

            TkAfter.new(0, 1) do
              @frame.pack_forget
              @on_success.call(recovered)
            end.start
          rescue => e
            TkAfter.new(0, 1) do
              @error_label.configure(text: "Error: #{e.message}", foreground: COLORS[:red_err])
              @verify_btn.configure(text: '  VERIFICAR RESPUESTAS  ', state: 'normal')
            end.start
          end
        end
      end

      def clear_answer_fields
        @answer_entries.each { |e| e.value = '' }
      end
    end
  end
end
