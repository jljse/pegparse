
module Pegparse
module BasicRules

  # Repetation rules (include this module into your parser class if needed)
  module RepeatRule

    # Rule for repeat of child + separator (e.g. function arguments)
    #   repeat_proc : repeating match (e.g. function argument)
    #   sp_proc : space match (if nil, no space is allowed)
    #   separator_proc : separator match (e.g. comma)
    #   is_last_sep_allowed : 
    #     Whether allow separator after last repetation.
    #     if false, separator can only appear between repetation.
    def repeat_separator(repeat_proc, sp_proc, separator_proc, is_last_sep_allowed: true)
      first_rep = bt_maybe{ repeat_proc.call() }
      unless first_rep
        return []
      end
      
      other_rep = bt_loop do
        sp_proc.call() if sp_proc
        separator_proc.call()
        sp_proc.call() if sp_proc

        repeat_proc.call()
      end

      if is_last_sep_allowed
        bt_maybe do
          sp_proc.call() if sp_proc
          separator_proc.call()
        end
      end

      return [first_rep, *other_rep]
    end

  end

end
end
