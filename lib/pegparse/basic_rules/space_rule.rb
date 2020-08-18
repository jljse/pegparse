
module Pegparse
module BasicRules

  # Spaces and Comment rules (include this module into your parser class if needed)
  module SpaceRule
    extend Pegparse::WrapModule

    # One line comment start symbol (allow array for multi symbol)
    def LINE_COMMENT()
      # "#"
      # ["#", "//"]
      nil
    end

    # Block comment start symbol
    def BLOCK_COMMENT_BEGIN()
      # "/*"
      nil
    end

    # Block comment end symbol
    def BLOCK_COMMENT_END()
      # "*/"
      nil
    end

    # ------------------------------------
    # rules
    # ------------------------------------

    def comment()
      rules = []
      if LINE_COMMENT()
        rules << proc{ line_comment() }
      end
      if BLOCK_COMMENT_BEGIN()
        rules << proc{ block_comment() }
      end

      bt_branch(*rules)
    end

    def line_comment()
      case LINE_COMMENT()
      when nil
        fail()
      when String
        str_notrace(LINE_COMMENT())
      when Array
        bt_branch(* LINE_COMMENT().map{|x| proc{ str_notrace(x) }})
      end
      regexp_notrace(/.*\n/)
      return LINE_COMMENT()
    end

    def block_comment()
      str_notrace(BLOCK_COMMENT_BEGIN())
      
      loop do
        regexp(Regexp.new("[^" + BLOCK_COMMENT_BEGIN()[0] + BLOCK_COMMENT_END()[0] + "]*"))
        if peek_str?(BLOCK_COMMENT_BEGIN())
          block_comment()
        elsif peek_str?(BLOCK_COMMENT_END())
          break
        else
          regexp(/./)
        end
      end
      
      str_notrace(BLOCK_COMMENT_END())
      return BLOCK_COMMENT_BEGIN() + BLOCK_COMMENT_END()
    end

    memoize def any_space_or_comment()
      prev_pos = current_pos()
      bt_loop do
        bt_branch(
          proc{ comment() },
          proc{ regexp(/[ \t\r\n]+/) },
        )
      end
      after_pos = current_pos()

      # This is special process to return text before current position
      return self.text.byteslice(prev_pos ... after_pos)
    end

    # Spaces (must contain newline)
    trace def lf()
      spaces = any_space_or_comment()
      if spaces.include?("\n")
        return spaces
      else
        failed(:lf)
      end
    end

    # Spaces (without newline)
    trace def inline_sp()
      spaces = any_space_or_comment()
      if spaces.include?("\n")
        failed(:inline_sp)
      elsif spaces.size == 0
        failed(:inline_sp)
      else
        return spaces
      end
    end
    
    # Spaces (without newline, could be blank)
    def inline_sp?()
      spaces = any_space_or_comment()
      if spaces.include?("\n")
        failed(:inline_sp)
      else
        return spaces
      end
    end
    
    # Spaces (allow newline)
    trace def sp()
      spaces = any_space_or_comment()
      if spaces.size == 0
        failed(:sp)
      else
        return spaces
      end
    end
    
    # Spaces (allow newline, could be blank)
    def sp?()
      any_space_or_comment()
    end

  end
end
end