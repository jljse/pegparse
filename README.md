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

`bt_branch` is PEG's `ordered choice operator('/')`. It takes any number of `proc`s and tries to match them up to down, and returns the result of first success. If none of them succeeded, then `bt_branch` throws `:failed`.

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

As PEG parsing process is not separated as lexer and parser, so handling of space characters is much strict then popular `lex/yacc`'s way.
Syntax has to care about all of the places to skip any spaces.
`SpaceRule` module provides basic rules to process space and comment.

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

Comment is similar to space but there is no lexer to tokenize, so we have to skip both of them together in the syntax. That's why `sp()` is provided to hide simple `regexp`.
In Pegparse, comment skipping is built into space skipping.

If you need comment syntax, you can override some methods to configure. Line comment consume text from the regexp pattern(`LINE_COMMENT()`), to end of the line. Block comment consume text from the regexp pattern(`BLOCK_COMMENT_BEGIN()`), to another pattern(`BLOCK_COMMENT_END()`). Block comment allows nesting (currently no way to inhibit nesting).


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

As string literal is very popular syntax for most programming languages,
`StringRule` module offeres helper method `string_like_literal(begin, end, breaks)`.
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

x = MyParser.new('"hello $x, bye"')
p x.string_literal_embedded()  # => ['hello ', :x, ', bye']
```

But Embedded-Expression is complicated, it matches expression, and result is not text but AST, so we can't concatinate them into simple one string. So, `string_like_literal` always returns array.


### Helpers(binary operator rule)

Most basic purpose of syntax parsing is arithmetic expression,
so Pegparse provide helper method.
But before that, I'll explain how helper is built.

```ruby
require 'pegparse'

class MyParser < Pegparse::Parser
  def number()
    regexp(/[0-9]+/).to_i
  end

  def mul()
    number()
    str('*')
    number()
  end
end

x = MyParser.new('2*3')
p x.mul()  # => 3  (return value of mul() is right operand now)
```

Start with calculator only allow single multiplication.
There's nothing difficult.

```ruby
  def mul()
    number()
    bt_loop {
      str('*')
      number()
    }
  end
```
```ruby
x = MyParser.new('2*3*4')
p x.mul()  # => [3, 4]  (return value is bt_loop's result now)
x.peek_eos?()  # => true
```

Now repitition is allowed. Still simple enough.

```ruby
  def mul()
    left = number()
    others = bt_loop {
      str('*')
      number()
    }
    [left, *others]
  end
```
```ruby
x = MyParser.new('2*3*4')
p x.mul()  # => [2, 3, 4]
```

Fix return value. It becomes better, but actually we need AST which represent evaluation order.

```ruby
  def mul()
    left = number()
    others = bt_loop {
      op = str('*')
      right = number()
      [op, right]
    }
    ret = left
    others.each do |op, r|
      ret = [op, ret, r]
    end
    return ret
  end
```
```ruby
x = MyParser.new('2*3*4')
p x.mul()  # => ["*", ["*", 2, 3], 4]
```

OK. Next, add new operator layer.

```ruby
  def mul()
    left = number()
    others = bt_loop {
      op = str('*')
      right = number()
      [op, right]
    }
    ret = left
    others.each do |op, r|
      ret = [op, ret, r]
    end
    return ret
  end

  def add()
    left = mul()
    others = bt_loop {
      op = str('+')
      right = mul()
      [op, right]
    }
    ret = left
    others.each do |op, r|
      ret = [op, ret, r]
    end
    return ret
  end
```
```ruby
x = MyParser.new('2*3*4+5*6')
p x.add()  # => ["+", ["*", ["*", 2, 3], 4], ["*", 5, 6]]
```

It should work, but a little bit complicated and not DRY. It should be possible to make wrap method.
What's the parameter should be? How about space skipping? ...
Here Pegparse provides helper method.

```ruby
require "pegparse"
require 'pegparse/basic_rules/space_rule'
require 'pegparse/basic_rules/biop_rule'

class BiopParser < Pegparse::Parser
  include Pegparse::BasicRules::SpaceRule
  include Pegparse::BasicRules::BiopRule

  def number()
    regexp(/[0-9]+/).to_i
  end

  def mul()
    left_biop(['*', '/'], proc{ sp?() }, proc{ number() }){|op, l, r| [op, l, r] }
  end

  def add()
    left_biop(['+', '-'], proc{ sp?() }, proc{ mul() }){|op, l, r| [op, l, r] }
  end
end

x = BiopParser.new('2*3*4+5*6')
p x.add()  # => ["+", ["*", ["*", 2, 3], 4], ["*", 5, 6]]
```

`BiopRule` module provides `left_biop` which is helper method for `left-associative binary operator`.
- 1st parameter is array of operators in same level.
- 2nd parameter is space matching before/after operator.
- 3rd parameter is lower level rule.
- Block should construct the result value.
- returns whole AST.

There isn't right-associative helper because normal recursive call is enough.


### Helpers(repeat rule)

Typical syntax contains repetition which consists of elements and separators.
For example, Array literal, Function parameters, etc.
Matching rule for them could be writtin like:
```
  def func_arguments
    ret = bt_maybe {
      first = expression()
      others = bt_loop {
        str(',')
        expression()
      }
      [first, *others]
    }
    ret || []
  end
```
This is not difficult if you're careful, but such pattern happens so many times that important syntax will be buried.  
`repeat_separator` is the helper for it.
```
class RepeatParser < Pegparse::Parser
  include Pegparse::BasicRules::RepeatRule

  ...

  def func_arguments()
    repeat_separator(proc{ expression() }, nil, proc{ str(',') })
  end
end
```
- 1st parameter is element matching.
- 2nd parameter is space matching between element and separator.
- 3rd parameter is separator matching.
- Keyword argument `is_last_sep_allowd` allows the trailing separator. Default value is `false`.  
   For example, use for syntax in which both `[a,b]` and `[a,b,]` are valid.


### Helpers(here-document rule)

First of all, `Pegparse`'s here-document support is very limited.
Here-document syntax and recursive-decsent parsing are bad chemistry.   
`Pegparse` aim to parse `Ruby`'s syntax, but it's too complicated to
handle in general way.
```
ary = []
XXX = 0

puts <<XXX
this is here-document
XXX

ary <<XXX
p "this is not here-document"
XXX
```
As you see above, `Ruby`'s parsing nose into semantic analysis.
So I gave up to keep following to `Ruby`.

Anyway, `Pegparse` have simplified here-document support. It acts like as follows:

- When parsing detect start symbol of here-document (like "<<EOS"),   
    then request `Pegparse` to callback content matcher on the next line-break.
- When line-break appears while space skipping, `Pegparse` call the callback.
- In the callback, context and final symbol of here-document (like "EOS") will be consumed.  
    The callback returns match result.
    
- Returns from the callback, `Pegparse` calls another callback which set the match result of contents to start symbol of here-document.

This mechanism works well in most case,
but backtrack around here-document does not work. 
Once some area interpreted as here-document, then such area change into
part of spaces. `Pegparse`'s backtrack doesn't cancel it.

Because of this limitation, you have to specificate syntax free from backtrack
of "<<EOF".  
Most easy workaround is, force binary `<<` operatar to require space around it,
and start symbol of here-document inhibit space between `<<` and symbol.

At last, `handle_heredoc` is the helper for here-document.
```
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
end

x = HeredocParser.new("<<EOS\nx\ny\nEOS\nx")
x.exp()   # => ["EOS", "x\ny\n"]
```

- 1st parameter is content matching. In usualy, here-document is kind of string,  
    so you can use StringRule helper.
- 2nd parameter is content setter. Block's argment is result of content matching.  
    Block's result value has no meaning.  
    This proc must hold the reference to receiver object of content,  
    which means you can't set content to variable simply like `ret = content`.  
    Because these callbacks are called on line-break, after `heredoc` finished  already.

- Note: line-break detection is functionality of `SpaceRule`,  
  so its method must be used to trigger the content of here-document,  
  like `sp()`, `sp?()` and `lf()`.

- Note: LF inside of block comment doesn't trigger the content of here-document.


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
