
module Pegparse
module BasicRules

  # Binary operator rules (include this module into your parser class if needed)
  module BiopRule
    extend Pegparse::WrapModule

    # Left-associative binary operator helper.
    #   op_strs : Array of operator string.
    #   space_match : Space matching proc.  If nil, no space around operator is allowed.
    #   child_match : Operand matching proc.
    #   block : {|operator, left-operand, right-operand|  combined AST value } .
    def left_biop(op_strs, space_match, child_match, &result_gen_block)
      op_match = proc{
        regexp( Regexp.new( op_strs.map{|x| '(' + Regexp.escape(x) + ')'}.join('|') ) )
      }

      left = child_match.call()
      rights = bt_loop do
        if space_match
          space_match.call()
        end
        op = op_match.call()
        if space_match
          space_match.call()
        end
        right = child_match.call()
    
        [op, right]
      end
    
      ret = left
      rights.each do |op, right|
        ret = result_gen_block.call(op, ret, right)
      end
      return ret
    end

  end

end
end