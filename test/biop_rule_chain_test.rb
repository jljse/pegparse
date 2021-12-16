# frozen_string_literal: true

require "test_helper"
require 'strscan'

class BiopRuleChainTest < Minitest::Test
  SampleBiopParser = Pegparse::BiopRuleChain.based_on(Pegparse::ParserBase)
  def test_initialize
    SampleBiopParser.new(nil)
  end

  class SampleWithoutCommentParser < Pegparse::ParserBase
    def line_comment
      backtrack()
    end

    def block_comment
      backtrack()
    end
  end
  SampleWithoutCommentBiopParser = Pegparse::BiopRuleChain.based_on(SampleWithoutCommentParser)
  def test_based_on
    parser = SampleWithoutCommentBiopParser.new(StringScanner.new(" \n #a\n \n"))
    parser._()
    assert_equal "#a", parser.peek("#a")
  end

  def test_4arith
    parser = SampleBiopParser.new(nil)
    parser
      .left_op(['+', '-'])
      .left_op(['*', '/'])
      .term(->{ parser.read(/[0-9]/) })

    assert_equal '1', parser.parse(StringScanner.new('1'))
    assert_equal ['+', '1', '2'], parser.parse(StringScanner.new('1+2'))
    assert_equal ['-', ['+', '1', ['*', '2', '3']], '4'], parser.parse(StringScanner.new('1+2*3-4'))
    assert_equal ['+', ['+', ['+', '1', '2'], '3'], '4'], parser.parse(StringScanner.new('1+2+3+4'))
  end

  SampleSkipUnderscoreBiopParser = Pegparse::BiopRuleChain.based_on(Pegparse::ParserBase) do
    def operator_sp
      read(/_?/)
    end

    def operand_sp
      read(/_?/)
    end
  end
  def test_based_on_with_block
    parser = SampleSkipUnderscoreBiopParser.new(nil)
    parser
      .left_op('?')
      .term(->{ parser.read(/[A-Z]/) })

    assert_equal ['?', ['?', 'A', 'B'], 'C'], parser.parse(StringScanner.new('A?B?C'))
    assert_equal ['?', ['?', 'A', 'B'], 'C'], parser.parse(StringScanner.new('A_?_B_?_C'))
    assert_equal ['?', 'A', 'B'], parser.parse(StringScanner.new('A_?_B ?_C'))
  end


end
