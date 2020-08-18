
module Pegparse
module BasicRules

  # String literal rules (include this module into your parser class if needed)
  module StringRule
    extend Pegparse::WrapModule

    # Rule for <"..."> like literal.
    #   Result is Array of chunk. (for the purpose of parsing "hello $x again" as ["hello ", $x, " again"].)
    #   begin_str : head of literal
    #   end_str : tail of literal
    #   break_strs : Array of special string under literal.
    #             When any string in break_strs appears in literal, &break_block whill be called.
    #   break_block : Handler for special string.  No parameter.
    #             You can consume special string and followings as much as needed in the block.
    #             If block result value is String, concatinate it to shibling chunk. (use for escape charcter)
    #             If block result value is not String, make separated chunk. (use for embedded variable etc.)
    def string_like_literal(begin_str, end_str, break_strs, &break_block)
      break_char = [end_str, *break_strs, "\n"].map{|x| x.byteslice(0)}

      ret = []
      str(begin_str)
      
      current_str_chunk = ""
      while true
        if break_char.include? current_text(1)
          if peek_str?(end_str)
            break
          else
            if break_strs.any?{|x| peek_str?(x)}
              blockresult = break_block.call
              case blockresult
              when String
                current_str_chunk << blockresult
              when nil
                ; # do nothing
              else
                ret << current_str_chunk if current_str_chunk.size > 0
                ret << blockresult
                current_str_chunk = ""
              end
            end
          end
        else
          # just continue
          current_str_chunk << regexp(/./)
        end
      end

      ret << current_str_chunk if current_str_chunk.size > 0
      str(end_str)
      return ret
    end
  end

end
end
