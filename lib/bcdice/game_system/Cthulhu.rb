# frozen_string_literal: true

module BCDice
  module GameSystem
    class Cthulhu < Base
      # ゲームシステムの識別子
      ID = 'Cthulhu'

      # ゲームシステム名
      NAME = 'クトゥルフ神話TRPG'

      # ゲームシステム名の読みがな
      SORT_KEY = 'くとうるふしんわTRPG'

      # ダイスボットの使い方
      HELP_MESSAGE = <<~INFO_MESSAGE_TEXT
        c=クリティカル値 ／ f=ファンブル値 ／ s=スペシャル

        1d100<=n    c・f・sすべてオフ（単純な数値比較判定のみ行います）

        ・cfs判定付き判定コマンド

        CC	 1d100ロールを行う c=1、f=100
        CCB  同上、c=5、f=96

        例：CC<=80  （技能値80で行為判定。1%ルールでcf適用）
        例：CCB<=55 （技能値55で行為判定。5%ルールでcf適用）

        ・組み合わせロールについて

        CBR(x,y)	c=1、f=100
        CBRB(x,y)	c=5、f=96

        ・抵抗表ロールについて
        RES(x-y)	c=1、f=100
        RESB(x-y)	c=5、f=96

        ※故障ナンバー判定

        ・CC(x) c=1、f=100
        x=故障ナンバー。出目x以上が出た上で、ファンブルが同時に発生した場合、共に出力する（テキスト「ファンブル＆故障」）
        ファンブルでない場合、成功・失敗に関わらずテキスト「故障」のみを出力する（成功・失敗を出力せず、上書きしたものを出力する形）

        ・CCB(x) c=5、f=96
        同上

      INFO_MESSAGE_TEXT

      register_prefix('CCB?', 'RESB?', 'CBRB?')

      def eval_game_system_specific_command(command)
        roll_skill_check(command) || roll_regist_check(command) || roll_combine_check(command)
      end

      private

      def roll_skill_check(command)
        parser = Command::Parser.new(/CCB?/, round_type: @round_type).enable_suffix_number.restrict_cmp_op_to(nil, :<=)
        parsed = parser.parse(command)
        unless parsed
          return nil
        end

        critical_fumble = parsed.command == "CC" ? 1 : 5
        broken_num = parsed.suffix_number || 0
        diff = parsed.target_number

        if parsed.cmp_op.nil?
          total = @randomizer.roll_once(100)
          return Result.new("(1D100) ＞ #{total}")
        end

        expr = "(1D100<=#{diff})"
        if broken_num > 0
          expr += " #{translate('Cthulhu.broken_number')}[#{broken_num}]"
        end

        total = @randomizer.roll_once(100)
        compare_result = compare(total, diff, critical_fumble, broken_num)

        compare_result.to_result.tap do |r|
          r.text = "#{expr} ＞ #{total} ＞ #{compare_result.text}"
        end
      end

      class CompareResult
        include Translate
        attr_accessor :success, :failure, :critical, :fumble, :special, :broken

        def initialize(locale)
          @locale = locale

          @success = false
          @failure = false
          @critical = false
          @fumble = false
          @special = false
          @broke = false
        end

        def text
          if critical && special
            translate("Cthulhu.critical_special")
          elsif critical
            translate("Cthulhu.critical")
          elsif special
            translate("Cthulhu.special")
          elsif success
            translate("success")
          elsif broken && fumble
            "#{translate('Cthulhu.fumble')}/#{translate('Cthulhu.broken')}"
          elsif broken
            translate("Cthulhu.broken")
          elsif fumble
            translate("Cthulhu.fumble")
          elsif failure
            translate("failure")
          end
        end

        def to_result
          Result.new.tap do |r|
            r.success = success
            r.failure = failure
            r.critical = critical
            r.fumble = fumble
          end
        end
      end

      def compare(total, target, critical_fumble, broken_number = 0)
        result = CompareResult.new(@locale)
        target_special = target / 5

        if (total <= target) && (total < 100)
          result.success = true
          result.special = total <= target_special
          result.critical = total <= critical_fumble
        else
          result.failure = true
          result.fumble = total >= (101 - critical_fumble)
        end

        if broken_number > 0 && total >= broken_number
          result.broken = true
          result.failure = true
          result.success = false
          result.special = false
          result.critical = false
        end

        return result
      end

      def roll_regist_check(command)
        m = /^(RESB?)(-?\d+)$/i.match(command)
        unless m
          return nil
        end

        critical_fumble = m[1] == "RES" ? 1 : 5
        value = m[2].to_i
        target = value * 5 + 50

        if target < 5
          return Result.failure("(1d100<=#{target}) ＞ #{translate('Cthulhu.automatic_failure')}")
        end

        if target > 95
          return Result.success("(1d100<=#{target}) ＞ #{translate('Cthulhu.automatic_success')}")
        end

        # 通常判定
        total_n = @randomizer.roll_once(100)
        compare_result = compare(total_n, target, critical_fumble)

        compare_result.to_result.tap do |r|
          r.text = "(1d100<=#{target}) ＞ #{total_n} ＞ #{compare_result.text}"
        end
      end

      def roll_combine_check(command)
        m = /^(CBRB?)\((\d+),(\d+)\)$/i.match(command)
        unless m
          return nil
        end

        critical_fumble = m[1] == "CBR" ? 1 : 5
        diff_1 = m[2].to_i
        diff_2 = m[3].to_i

        total = @randomizer.roll_once(100)

        result_1 = compare(total, diff_1, critical_fumble)
        result_2 = compare(total, diff_2, critical_fumble)

        rank =
          if result_1.success && result_2.success
            translate("success")
          elsif result_1.success || result_2.success
            translate("Cthulhu.partial_success")
          else
            translate("failure")
          end

        Result.new.tap do |r|
          r.text = "(1d100<=#{diff_1},#{diff_2}) ＞ #{total}[#{result_1.text},#{result_2.text}] ＞ #{rank}"
          r.critical = result_1.critical || result_2.critical
          r.fumble = result_1.fumble || result_2.fumble
          r.condition = result_1.success || result_2.success
        end
      end
    end
  end
end
