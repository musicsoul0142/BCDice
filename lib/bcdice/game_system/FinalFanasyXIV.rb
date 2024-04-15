# frozen_string_literal: true

module BCDice
  module GameSystem
    class Template < Base
      # ゲームシステムの識別子
      ID = "FinalFanasyXIV"

      # ゲームシステム名
      NAME = "FINAL FANTSY XIV TTRPG"

      # ゲームシステム名の読みがな
      SORT_KEY = "ふあいなるふあんたしい14TTRPG"

      HELP_MESSAGE = <<~TEXT
        ここにヘルプメッセージを記述します。
        このように改行も含めることができます。
      TEXT

      register_prefix()

      def eval_game_system_specific_command(command)
        return nil
      end
    end
  end
end
