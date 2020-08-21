
module Pegparse
module BasicRules

  # String literal rules (include this module into your parser class if needed)
  module StringRule
    extend Pegparse::WrapModule

    # Rule for <"..."> like literal.
    #   Result is Array of chunk. (for the purpose of parsing "hello $x again" as ["hello ", $x, " again"].)
    #   begin_regexp : head of literal
    #   end_regexp : tail of literal
    #   break_strs : Array of special string under literal.
    #             When any string in break_strs appears in literal, &break_block whill be called.
    #             WARN: end_regexp is only invoked at break_strs, so you must add something.
    #   break_block : Handler for special string.  No parameter.
    #             You can consume special string and followings as much as needed in the block.
    #             If block result value is String, concatinate it to shibling chunk. (use for escape charcter)
    #             If block result value is not String, make separated chunk. (use for embedded variable etc.)
    def string_like_literal(begin_regexp, end_regexp, break_strs, is_multiline: false, &break_block)
      if break_strs == nil || break_strs.empty?
        raise "break_strs is required. end_regexp is only invoked at break_strs, so you must add something."
      end

      break_chars = break_strs.map{|x| x.byteslice(0)}
      break_chars << "\n" unless is_multiline

      ret = []
      regexp(begin_regexp)
      
      current_str_chunk = ""
      while true
        if break_chars.include? current_text(1)
          if peek_regexp?(end_regexp)
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
          if is_multiline
            current_str_chunk << regexp(/.|\n/)
          else
            current_str_chunk << regexp(/./)
          end
        end
      end

      ret << current_str_chunk if current_str_chunk.size > 0
      regexp(end_regexp)
      return ret
    end
  end

end
end
