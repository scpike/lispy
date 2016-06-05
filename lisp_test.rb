#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'lisp'

class LispTests < Minitest::Test
  def setup 
    @evaluator = Evaluator.new
    @env = @evaluator.env
  end

  [["(+ 1 2)", [LispSymbol.new('+'), 1, 2]],
   ["(+ 1 (* 2 3))", [LispSymbol.new('+'), 1, [LispSymbol.new('*'), 2, 3]]],
   ["(begin (define r 10) (* pi (* r r)))", [LispSymbol.new('begin'),
                                             [LispSymbol.new('define'), LispSymbol.new('r'), 10],
                                             [LispSymbol.new('*'), LispSymbol.new('pi'), [LispSymbol.new('*'),
                                                                                          LispSymbol.new('r'),
                                                                                          LispSymbol.new('r')]]]]
  ].each_with_index do |(i, o), idx|
    define_method("test_parse_#{idx}") do
      p = Parser.new
      assert_equal o, p.parse(i)
    end
  end

  def eval_lisp(exp)
    evaluator = @evaluator.eval_lisp(exp)
  end

  def test_eval_math_ops
    assert_equal 5, eval_lisp("(+ 1 4)")
    assert_equal 4, eval_lisp("(* 1 4)")
    assert_equal 7, eval_lisp("(+ 1 4 2)")
    assert_equal 1, eval_lisp("(- 5 4)")
  end

  def test_cmp_ops
    assert_equal true, eval_lisp("(= 5 5)")
    assert_equal true, eval_lisp("(= 5 5 5)")
    assert_equal false, eval_lisp("(= 5 5 4)")
    assert_equal false, eval_lisp("(= 5 4)")
    assert_equal false, eval_lisp("(= false true)")
    assert_equal true, eval_lisp("(= nil nil)")
    assert_equal true, eval_lisp("(= false false)")

    assert_equal true, eval_lisp("(> 4 3)")
    assert_equal false, eval_lisp("(> 4 4)")
    assert_equal true, eval_lisp("(< 3 4)")
    assert_equal true, eval_lisp("(<= 3 3)")
  end

  def test_define
    eval_lisp("(define x 3)")
    assert_equal 3, @env["x"]

    assert_equal 30, eval_lisp("(* x 10)")
    assert_equal 27, eval_lisp("(* x (+ 5 4))")
  end

  def test_lambda
    assert_equal 3, eval_lisp("((lambda (x y) (+ x y)) 1 2)")

    eval_lisp("(define area (lambda (x y) (* x y)))")
    assert_equal 20, eval_lisp("(area 4 5)")
  end

  def test_quote
    assert_equal [1, 2, 3], eval_lisp("(quote (1 2 3))")
  end

  def test_eval
    assert_equal 1, eval_lisp("(eval (quote (- 3 2)))")
  end

  def test_conditionals
    assert_equal 1, eval_lisp("(if true 1 2)")
    assert_equal 7, eval_lisp("(if true (+ 3 4) 2)")
    assert_equal 3, eval_lisp("(if (< 4 3) 4 3)")
  end

  def test_lists
    assert_equal [1, 2, 3], eval_lisp("(cons 1 (quote (2 3)))")
  end
end
