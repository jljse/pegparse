
module Pegparse
module BasicRules

  # string literal rules (include this module into your parser class if needed)
  module StringRule
    extend Pegparse::WrapModule

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
