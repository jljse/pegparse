# Pegparse

Pegparse is parsing library for recursive descent parser to implement PEG.
Similar to Treetop, but more thin abstraction so familiar to programmers
who want to write code by oneself.

Pegparse offers PEG's mechanism
- backtracking
- memoize

Pegparse offers some helpers to ease build common syntax.
- binary operator
- space handling
- string literal
- heredoc literal

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pegparse'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pegparse

## Usage

I'll explain how the code looks like.
Refer test code to see more samples.

### First step
```ruby
require 'pegparse'

class MyParser < Pegparse::Parser
end

x = MyParser.new("this is test")
p x.str('this')  # => "this"
p x.current_pos  # => 4
p x.regexp(/ is /)  # => " is "
p x.str('bug')  # => throws :failed
```

Define your parser class inherit `Pegparse::Parser`.
Basic policy is here:
- Method means matching.
- If matching succeeded, returns matching result and move position.
- If matching failed, throws `:failed` and position goes to somewhere.

In this point, it similar to restricted `StringScanner`.
Primitive matching method is `str` and `regexp`.

### Basics
```ruby
require 'pegparse'

class MyParser < Pegparse::Parser
  def integer()
    regexp(/[0-9]+/)
  end

  def decimal()
    int = integer()
    dec = bt_maybe {
      str('.')
      integer()
    }
    return int + (dec || "")  # => "123" + "45"
  end
end

x = MyParser.new("123.45 67.x")
p x.decimal()  # => "12345"
x.str(' ')
p x.decimal()  # => "67"
p x.str('.')  # => "."
```

You can define your rules and call them as usual.
`bt_maybe` (`bt` stand for "backtrack") is representation for PEG's `optional operator(?)`. It tries to proceed inside of block. If succeeded, `bt_maybe` returns value of block, in this case, `integer()`'s result, `'45'`.
If failed, `bt_maybe` returns `nil`. Even when matching failed in the middle of the block, `bt_maybe` rollbacks the position gracefully.

As you see, matching rule is just a method, so you can process partial matching result freely.

### PEG operators

```ruby
  def hyhpen_a()
    y = bt_loop {
      str('-')
      regexp(/[a-z]/)  
    }
    return y  # => ["a", "b", "c"]
  end
```

`bt_loop` is PEG's `zero-or-more operator('*')`. It returns array of block's result for each repeats. If no repeat succeeded, `bt_loop` returns `[]`.   
`bt_loop_required` is PEG's `one-or-more operator('+')`.  


```ruby
  def dot_1()
    str('.')
    z = bt_branch(
      proc{ str('1') },
      proc{ str('2') },
      proc{ str('3') },
    )
    z  # => '2'
  end
```

`bt_branch` is PEG's `ordered choice operator('/')`. It takes any number of `proc`s and tries to match them up to down, and returns the result of first success. If none of them succeeded, then bt_branch throws `:failed`.

```ruby
  def ahead()
    x = bt_lookahead {
      str('x')
    }
    str('x')
    bt_lookahead_deny {
      str('x')
    }
    str('y')
  end
```

`bt_lookahead` is PEG's `and-predicate operator('&')`. If matching succeeded, it returns block's value as result and rollback context position, then goes next step. If matching failed, `bt_lookahead` throws `:failed`.  
`bt_lookahead_deny` is PEG's `not-predicate operator('!')`. If matching failed, returns nothing and rollback context position, then goes next step. If matching succeeded, `bt_lookahead_deny` throws `:failed`.

### Memoize

```ruby
  memoize def x()
    regexp(/[a-z]+/)
  end

  def y()
    bt_branch(
      proc{ x(); str(' '); x(); str('.') },  # => when last '.' fails...
      proc{ x(); str(' '); x(); str('?') },  # => both x() is cached.
    )
  end
```

PEG's parsing is deterministic, so whenever you parse specific rule at  specific position, parsing result must be always same. Pegparse offers caching mechanism by marking any method with `memoize`. If you call `x`, it matches to `regexp` and return result, `Parser`'s instance keep the result into cache. If you try to call `x` next time at the same position, Pegparse returns result from chache to omit `x` execution.  
Actually I'm not sure such caching really contribute to the performance of parsing some usual programming language, because most of such syntax is LL(1).


### Helpers(space rule)

```ruby
require 'pegparse'
require 'pegparse/basic_rules/space_rule'

class MyParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule

  def x()
    str(',');  sp()    # similar to /\s+/
    str(',');  sp?()   # similar to /\s*/
    str(',');  inline_sp()    # similar to /[ \t]*/
    str(',');  inline_sp?()   # similar to /[ \t]+/
    str(',');  lf()    # similar to /[ \t]*\n\s*/
  end
end
```

As PEG parsing has to work as lexer and parser at once, handling of space characters is much strict then popular lex/yacc's way.
Syntax have to care about all of the places to skip the space.
`SpaceRule` provides basic space rules, comment rules.

```ruby
require 'pegparse'
require 'pegparse/basic_rules/space_rule'

class MyParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule

  def LINE_COMMENT()  # override
    %r|//|
  end

  def BLOCK_COMMENT_BEGIN()  # override
    %r|/\*|
  end

  def BLOCK_COMMENT_END()  # override
    %r|\*/|
  end

  def x()
    str('x')
    sp?()    # all comment is automatically skipped
    str('y')
  end
end
```

Comment is kind of space. There is no lexer so we have to skip them together with space IN the syntax. That's why `sp()` is provided to hide simple `regexp`.
In Pegparse, comment skipping is built into space skipping.

If you have comment syntax, override some methods. Line comment consume text from the regexp pattern, to end of the line. Block comment consume text from the regexp pattern, to another pattern. Block comment allows nesting (currently no way to inhibit nesting).


### Helpers(string literal rule)

```ruby
require 'pegparse'
require 'pegparse/basic_rules/string_rule'

class MyParser < Pegparse::Parser
  include Pegparse::BasicRules::StringRule

  def string_literal_basic
    string_like_literal(/"/, /"/, ['"'])
  end

  def string_literal_escape
    string_like_literal(/"/, /"/, ['"', '\\']) do
      bt_branch(
        proc{ str('\\n'); "\n" },
        proc{ str('\\t'); "\t" },
        proc{ str('\\"'); '"' },
      )
    end
  end
end

x = MyParser.new('"test"')
p x.string_literal_basic()  # => ['test']
x = MyParser.new('"te\nst"')
p x.string_literal_basic()  # => ['te\nst']  ('\' is '\', 'n' is 'n')
x = MyParser.new('"te\nst"')
p x.string_literal_escape()  # => ["te\nst"]  ('\n' is "\n")
```

As string literal is very popular syntax for most languages,
Pegparse offeres helper method `string_like_literal(begin, end, breaks)`.
The 3rd parameter takes array of string which requires special handling.
When "breaks" found, firstly check whether it matches the end pattern, secondly block is called. Block implement special handling and returns parsing result.

Why `string_like_literal` returns array?  
Special handling mostly categorize into 2 usage. Escaping and Embedded-Expression. Escaping is simple, it matches something(like `'\n'`) and returns some character, and concatinate to shibling characters around it.

```ruby
require 'pegparse'
require 'pegparse/basic_rules/string_rule'

class MyParser < Pegparse::Parser
  include Pegparse::BasicRules::StringRule

  def string_literal_embedded
    string_like_literal(/"/, /"/, ['"', '\\', '$']) do
      bt_branch(
        proc{ str('\\$'); '$' },
        proc{
          str('$')
          sym = regexp(/[a-z]+/)
          sym.to_sym
        },
      )
    end
  end
end

x = MyParser.new('hello $x, bye')
p x.string_literal_embedded()  # => ['hello ', :x, ', bye']
```

But Embedded-Expression is complicated, it matches expression, and result is not text but AST, so we can't concatinate them into simple one string. So, `string_like_literal` always returns array.

### Helpers(binary operator rule)
W.I.P

### Helpers(repeat rule)
W.I.P

### Helpers(here-document rule)
W.I.P

### Debug
W.I.P

### Error
W.I.P



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pegparse.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
