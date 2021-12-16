require_relative 'parser_base'

# Binary operator rule helper.
module Pegparse::BiopRuleChain
  # @!parse include Pegparse::ParserCore

  # Create new parser class derived from passed one.
  # If you want to customize parser behavior, override method in exec_block.
  # @return [Class<Pegparse::BiopRuleChainImitation>]
  def self.based_on(parser_class, &exec_block)
    raise ArgumentError unless parser_class.ancestors.include?(Pegparse::ParserBase)

    klass = Class.new(parser_class) do
      include Pegparse::BiopRuleChain
    end
    klass.class_exec(&exec_block) if exec_block

    klass
  end

  def initialize(scanner_or_context)
    super(scanner_or_context)
    @start_rule_symbol = :start_rule
    @operators = []
    @term = nil
  end

  # Default construction of matching result. (override this if you want)
  def construct_result(lhs, op, rhs)
    [op, lhs, rhs]
  end

  # Default matching rule of spaces before operator. (override this if you want)
  # This rule will be used when you pass string to #left_op.
  def operator_sp
    sp()
  end

  # Default matching rule of spaces before operand. (override this if you want)
  def operand_sp
    sp()
  end

  # Create match proc for operator.
  # @param operator_matcher [Array, Proc, String, Regexp]
  # @return [Proc]
  private def get_operator_matcher(operator_matcher)
    if operator_matcher.is_a? Array
      ops = operator_matcher.map{|x| get_operator_matcher(x)}
      return ->{
        choice(*ops)
      }
    end
    if operator_matcher.is_a? Proc
      return operator_matcher
    end
    if operator_matcher.is_a?(String) || operator_matcher.is_a?(Regexp)
      return ->{
        operator_sp()
        op = read(operator_matcher)
      }
    end
    raise ArgumentError
  end

  # Add left-associative binary operators.
  # Call in order of operators precedence.
  # If you have multiple operators in same precedence, pass Array as parameter.
  # @param operator_matcher [String, Regexp, Array, Proc]
  # @return [Pegparse::BiopRuleChainImitation]
  def left_op(operator_matcher)
    @operators << get_operator_matcher(operator_matcher)
    self
  end

  # Set terminal matching rule.
  # @param term_block [Proc]
  def term(term_block)
    @term = term_block
    nil
  end

  # Match expression of the operators which have specified precedence level.
  private def match(operator_level)
    return @term.call if operator_level >= @operators.size

    lhs = match(operator_level + 1)

    operands = zero_or_more {
      op = choice(*@operators[operator_level])
      operand_sp()
      rhs = match(operator_level + 1)

      [op, rhs]
    }

    tree = operands.inject(lhs) {|subtree, operand|
      construct_result(subtree, operand[0], operand[1])
    }
  end

  # entry point
  private def start_rule
    match(0)
  end
end

# this is an imitation class just for documentation.
# actual runtime never use this instance.
class Pegparse::BiopRuleChainImitation < Pegparse::ParserBase
  include Pegparse::BiopRuleChain
end

