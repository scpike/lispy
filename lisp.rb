#!/usr/bin/env ruby

require 'readline'

def tokenize(str)
  str
    .gsub("\n", ' ')
    .gsub('(', '( ').gsub(')', ' )')
    .gsub(/^\(/, '')
    .gsub(/\)$/, '')
    .split(/\s+/)
    .reject { |s| s.strip == '' }
end

LispSymbol = Struct.new(:val) do
  def ==(other)
    other.to_s == to_s
  end

  def to_s
    val.to_s
  end
end

# Parser a bit of lisp code into a ruby data structure
class Parser
  def typeify(t)
    if t =~ /^-?\d+$/
      t.to_i
    elsif t =~ /^\d+\.\d+$/
      t.to_f
    elsif t =~ /"/
      t.to_s.sub(/^"/, '').sub(/"$/, '')
    elsif t == 'nil'
      nil
    elsif t == 'false'
      false
    elsif t == 'true'
      true
    else
      LispSymbol.new(t)
    end
  end

  def parse(str)
    acc = []
    instack = 0
    tokenize(str).each do |t|
      ary = acc
      instack.times { |_t| ary = ary.last }

      if t == '('
        instack += 1
        ary << []
      elsif t == ')'
        instack -= 1
      else
        ary << typeify(t)
      end
    end
    acc
  end
end

# Evaluate a bit of lisp code, returning the result
class Evaluator
  attr_accessor :env
  def initialize(env = nil)
    @env = env || standard_env
  end

  def builtin_eq(*args)
    i = args.shift
    args.each do |a|
      return false unless a == i
    end
    true
  end

  def standard_env
    env = {
      '=' => method(:builtin_eq),
      'first' => -> (xs) { xs.first },
      'last' => -> (xs) { xs.last },
      'drop' => -> (xs) { xs.drop },
      'cons' => -> (x, xs) { [x] + xs }
    }

    %w(> >= < <=).each { |cmp| env[cmp] = -> (x, y) { x.send(cmp, y) } }

    %w(+ * / -).each do |op|
      env[op] = -> (*args) { args.reduce { |a, e| a.send(op, e) } }
    end

    env
  end

  def make_lambda(args, exp, env)
    local_env = env.dup
    proc do |*local_args|
      args.zip(local_args).each { |a, v| local_env[a.to_s] = v }
      eval_toks(exp, local_env)
    end
  end

  def eval_toks(t, env)
    t = t.first if t.is_a?(Array) && t.count <= 1

    return env[t.to_s] if t.is_a?(LispSymbol)
    return t unless t.is_a?(Array)

    if t[0] == 'lambda'
      make_lambda t[1], t[2], env
    elsif t[0] == 'defn'
      (_, fname, argl, exp) = t
      env[fname.to_s] = make_lambda(argl, exp, env)
    elsif t[0] == 'doall'
      (_, *exps) = t
      exps.map { |e| eval_toks(e, env) }.last
    elsif t[0] == 'if'
      (_, pred, texp, fexp) = t
      eval_toks(pred, env) ? eval_toks(texp, env) : eval_toks(fexp, env)
    elsif t[0] == 'define'
      env[t[1].to_s] = eval_toks(t[2], env)
    elsif t[0] == 'quote'
      t[1]
    elsif t[0] == 'eval'
      eval_toks(eval_toks(t[1], env), env)
    elsif t.is_a?(Array)
      opname = t.shift
      op = eval_toks(opname, env)
      if op
        op.call(*t.map { |y| eval_toks(y, env) })
      else
        fail NoMethodError, "Unrecognized operator #{opname}"
      end
    end
  end

  def eval_lisp(str, env = nil)
    env ||= @env
    parser = Parser.new
    eval_toks parser.parse(str), env
  end
end

def repl
  evaler = Evaluator.new
  while (buf = Readline.readline('lispy> ', true))
    begin
      print '-> ', evaler.eval_lisp(buf).inspect, "\n"
    rescue NoMethodError => e
      print "$NoMethodError: #{e.message}\n"
    rescue TypeError => e
      print "$TypeError: -> #{e.message}\n"
    end
  end
end

def eval_file(f)
  code = File.read(f)
  evaler = Evaluator.new
  code = ''"
(doall
  #{code})
"''
  evaler.eval_lisp(code)
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.any?
    p eval_file ARGV[0]
  else
    repl
  end
end
