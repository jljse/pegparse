require_relative 'test_helper'
require "pegparse"

class BasicParser < Pegparse::Parser
  def comma()
    str(',')
  end

  def number()
    s = regexp(/[0-9]+/)
    s.to_i
  end

  def hex()
    s = regexp(/0x[0-9a-f]+/)
    s.hex
  end

  def number_comma_hex()
    n = number()
    comma()
    h = hex()
    n + h
  end
end

class PegparseBasicTest < Minitest::Test
  def test_number()
    x = BasicParser.new("123")
    assert_equal 123, x.number()
    assert_equal 3, x.current_pos()
    assert x.peek_eos?()

    x = BasicParser.new("a123")
    assert_throws(:failed){ x.number() }

    x = BasicParser.new("123a")
    assert_equal 123, x.number()
    assert_equal 3, x.current_pos()
    assert !x.peek_eos?()
  end

  def test_hex()
    x = BasicParser.new("0x23")
    assert_equal 0x23, x.hex()
    assert_equal 4, x.current_pos()
    assert x.peek_eos?()

    x = BasicParser.new("00x23")
    assert_throws(:failed){ x.hex() }

    x = BasicParser.new("0x2ax")
    assert_equal 0x2a, x.hex()
    assert_equal 4, x.current_pos()
    assert !x.peek_eos?()
  end

  def test_number_comma_hex()
    x = BasicParser.new("1,0xa")
    assert_equal 1, x.number()
    assert_equal ',', x.comma()
    assert_equal 0xa, x.hex()
    assert x.peek_eos?()

    x = BasicParser.new("2,0xb,")
    assert_equal 2+0xb, x.number_comma_hex()

    x = BasicParser.new("1,xa")
    assert_throws(:failed){ x.number_comma_hex() }
  end

end
