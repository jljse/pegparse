# frozen_string_literal: true

require "test_helper"
require 'strscan'

class ParserCoreTest < Minitest::Test
  def test_initialize
    Pegparse::ParserCore.new(StringScanner.new('foo'))
  end


  class LoopParser < Pegparse::ParserCore
    def test
      zero_or_more {
        read(/[0-9]/)
      }
    end
  end
  def test_loop
    parser = LoopParser.new(StringScanner.new('123a'))
    assert_equal(%w[1 2 3], parser.test)
  end


  class ChoiceParser < Pegparse::ParserCore
    def test
      choice(
        ->{ read(/0+/) },
        ->{ read(/1+/) },
        ->{ read(/2+/) },
      )
    end
  end
  def test_choice
    parser = ChoiceParser.new(StringScanner.new('1122a'))
    assert_equal("11", parser.test)
    assert_equal("22", parser.test)
    assert_throws(:backtrack){ parser.test }
  end


  class NumberParser < Pegparse::ParserCore
    rule def test
      int_part = one_or_more {
        read(/[0-9]/)
      }
      decimal_part = optional {
        read('.')
        one_or_more {
          read(/[0-9]/)
        }
      }
      [int_part, decimal_part]
    end
  end
  def test_number
    parser = NumberParser.new(StringScanner.new('123'))
    assert_equal([%w(1 2 3), nil], parser.test)

    parser = NumberParser.new(StringScanner.new('123.a'))
    assert_equal([%w(1 2 3), nil], parser.test)

    parser = NumberParser.new(StringScanner.new('123.45'))
    assert_equal([%w(1 2 3), %w(4 5)], parser.test)

    parser = NumberParser.new(StringScanner.new('xxx'))
    assert_throws(:backtrack){ parser.test }
    assert_equal([[[0, 0], :test], [[0, 0], /[0-9]/]], parser.best_errors.first)
  end

  class HeredocTest < Pegparse::ParserCore
    def test1
      read('MARK1')
      doc1 = borrow_next_line {
        body = read(/.*\n/)
        read(/^END\n/)
        body
      }
      read('NOTMATCH')
    end

    def test2
      read('MARK1')
      doc1 = borrow_next_line {
        body = read(/.*\n/)
        read(/^END\n/)
        body
      }
      read(',')
      read('MARK2')
      doc2 = borrow_next_line {
        body = read(/.*\n/)
        read(/^END\n/)
        body
      }
      read(";\n")
      borrowed_area()
      borrowed_area()
      read('EOS')
      [doc1, doc2]
    end

    def test
      choice(
        ->{ test1 },
        ->{ test2 },
      )
    end
  end
  def test_heredoc
    parser = HeredocTest.new(StringScanner.new("MARK1,MARK2;\nxxx\nEND\nyyy\nEND\nEOS"))
    assert_equal(["xxx\n", "yyy\n"], parser.test)
  end

end
