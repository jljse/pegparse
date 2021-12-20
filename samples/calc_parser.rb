require_relative '../lib/pegparse'

module Pegparse::Sample
end

class Pegparse::Sample::CalcParser < Pegparse::ParserBase
  def initialize(context_or_scanner)
    super(context_or_scanner)
    self.start_rule_symbol = :expression
  end

  CalcBiopParser = Pegparse::BiopRuleChain.based_on(self) do
    def operator_sp
      read(/ */)
    end
    def operand_sp
      read(/ */)
    end
    def construct_result(lhs, op, rhs)
      case op
      when '+'
        lhs + rhs
      when '-'
        lhs - rhs
      when '*'
        lhs * rhs
      when '/'
        lhs / rhs
      end
    end
  end
  rule def expression
    biop = CalcBiopParser.new(nil)
    biop
      .left_op(['+', '-'])
      .left_op(['*', '/'])
      .term(->{ term() })
    biop.parse(@context)
  end

  rule def term
    choice(
      ->{
        read(/[0-9]+(\.[0-9]+)?/).to_f
      },
      ->{
        read('(')
        exp = expression()
        read(')')
        exp
      }
    )
  end

end
