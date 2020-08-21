require_relative 'test_helper.rb'
require 'pegparse'
require 'pegparse/basic_rules/space_rule'
require 'pegparse/basic_rules/heredoc_rule'
require 'pegparse/basic_rules/string_rule'

class HeredocParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule
  include Pegparse::BasicRules::HeredocRule
  include Pegparse::BasicRules::StringRule

  def heredoc()
    str('<<')
    sym = regexp(/[A-Z]+/)
    ret = [sym, nil]
    
    handle_heredoc(
      proc{
        string_like_literal(
            //, /^\s*#{Regexp.escape(sym)}$/, [' ', sym[0]], is_multiline: true)
      },
      proc{|content|
        ret[1] = content
      }
      )

    ret
  end

  def exp()
    h = heredoc()
    sp?()
    str('x')
    h
  end

  def exp2()
    str('(')
    h1 = heredoc()
    str(',')
    sp?()
    h2 = heredoc()
    str(')')
    sp?()
    str('x')
    [h1, h2]
  end

  def exp3()
    bt_branch(
      proc{
        h = heredoc()
        sp?()
        str('x')
        h
      },
      proc{
        h = heredoc()
        sp?()
        str('y')
        h
      },
    )
  end

end

class PegparseHeredocTest < Minitest::Test
  def test_normal
    x = HeredocParser.new("<<EOS\nx\ny\nEOS\nx")
    assert_equal ["EOS", ["x\ny\n"]], x.exp()
  end

  def test_heredocs
    x = HeredocParser.new("(<<EOSA, <<EOSB)\nx\ny\nEOSA\na\nb\nEOSB\nx")
    assert_equal [["EOSA", ["x\ny\n"]], ["EOSB", ["a\nb\n"]]], x.exp2()
  end

  def test_backtrack
    x = HeredocParser.new("<<EOS\nx\ny\nEOS\ny")
    assert_equal ["EOS", ["x\ny\n"]], x.exp3()
  end
end

