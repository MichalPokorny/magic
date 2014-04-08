#!/usr/bin/ruby -w
$: << '.'
require_relative 'machine'
require_relative 'sms-interface'
require_relative 'human-source-convertor'
require 'test/unit'

class MachineTest < Test::Unit::TestCase
	def setup
		@machine = Machine.new
	end

	def test_numeric_resolve
		assert_equal 0, @machine.numeric_resolve('a')
		assert_equal 9, @machine.numeric_resolve('bjg')
		assert_equal 22, @machine.numeric_resolve('ihh')
		assert_equal 1, @machine.numeric_resolve('b')
		assert_equal 5, @machine.numeric_resolve('bf')
		assert_equal 15, @machine.numeric_resolve('bfa')
		assert_equal 100, @machine.numeric_resolve('bafak')
		assert_equal 100, @machine.numeric_resolve('hafak')
		assert_equal 100, @machine.numeric_resolve('hgiak')
		assert_equal 101, @machine.numeric_resolve('bafai')
	end

	def assert_runs_to(program, input, output)
		@machine.input = input
		@machine.run_program program
		assert_equal output, @machine.output
	end

	def test_output_without_args
		assert_runs_to "i", [], [42]
	end

	def test_print_1_through_100
		# load 1, set 0, label L, get $0, minus 100, overflow?, if, goto G, goto E,
		# label G, get $0, out $, plus 1, set 0, goto L, label E
		assert_runs_to "ah ba ll alg dbafai f j gg ge lg ala il ce ba gl le", [], (1..100).to_a
	end

	def test_print_10
		assert_runs_to "abae il", [ ], [ 10 ]
	end

	def test_echo_if_nonzero
		program = "h j il"
		assert_runs_to program, [ 10 ], [ 10 ]
		assert_runs_to program, [ 0 ], [ ]
	end

	def test_bigger_one
		program = "ha hb ala dlb f j gb ila gl lb ilb ll"
		assert_runs_to program, [ 10, 20 ], [ 20 ]
		assert_runs_to program, [ 20, 19 ], [ 20 ]
		assert_runs_to program, [ 5, 0 ], [ 5 ]
	end

	def test_runs_until_timeout
		program = "aa ik ga"
		@machine.instruction_limit = 1_000
		assert_raise Machine::ExecutionTimeout do
			@machine.run_program program
		end
	end

	def test_xor
		program = "ab ba ila ala kb ba ila ala kb ba ila"
		assert_runs_to program, [], [1, 0, 1]
	end
end

require_relative 'tasks'

class TaskOutputTenTest < Test::Unit::TestCase
	def test_trivial_solutions_and_nonsolutions
		task = Tasks::OutputConstant.new(1)

		assert task.correct_solution?('ab il')
		assert task.correct_solution?('ib kk kk')
		assert !task.correct_solution?('aa il')
		assert !task.correct_solution?('')

		# Loops
		assert !task.correct_solution?('kk gk')

		task = Tasks::OutputConstant.new(5)
		assert task.correct_solution?('abc il')
	end
end

class TaskOutputEternal < Test::Unit::TestCase
	def test_trivial_solutions_and_nonsolutions
		task = Tasks::OutputEternal.new(9)

		assert !task.correct_solution?('aa il')
		assert !task.correct_solution?('')

		# Loops
		assert !task.correct_solution?('kk gk')

		assert task.correct_solution?('ibad g')
	end
end

class TaskPrint1Through100Test < Test::Unit::TestCase
	def test_task
		task = Tasks::Print1Through100.new

		assert task.correct_solution?(<<-END)
			ah ba ll alg dbafai f j gg ge lg ala il ce ba gl le
		END
		assert !task.correct_solution?(<<-END)
			ah ba ll alg dbafaj f j gg ge lg ala il ce ba gl le
		END
	end
end

class SMSInterfaceTest < Test::Unit::TestCase
	def test_interaction
		tasks = {
			"100" => SMSInterface::Task.new(Tasks::OutputConstant.new(5), 10)
		}
		robot = SMSInterface.new(tasks)
		
		assert robot.interact("Ahoj") =~ /CHYBA/
		assert robot.interact("99 abc") =~ /CHYBA/
		assert robot.interact("100 xyzzy") =~ /CHYBA/
		assert robot.interact("100 abc") =~ /WA/
		assert robot.interact("100 kk gkb") =~ /TO/
		assert robot.interact("100 h") =~ /OI/
		assert robot.interact("100 abc il") =~ /Gratuluji/
	end

	def test_points_text
		tasks = {
			"100" => SMSInterface::Task.new(Tasks::OutputConstant.new(5), 10)
		}
		robot = SMSInterface.new(tasks)
		assert robot.points_text(102.4).include? "102"
	end
end

class HumanSourceConvertorTest < Test::Unit::TestCase
	def setup
		@convertor = HumanSourceConvertor.new
		@machine = Machine.new
	end

	def test_comment_stripping
		assert_equal "Ahoj", @convertor.strip_line_comments("Ahoj")
		assert_equal "Ahoj", @convertor.strip_line_comments("Ahoj#Svete")
		assert_equal "Ahoj", @convertor.strip_line_comments("Ahoj//Svete")
	end

	def test_decimal_to_ternary
		assert_equal "0", @convertor.decimal_to_ternary(0)
		assert_equal "100", @convertor.decimal_to_ternary("9")
		assert_equal "201", @convertor.decimal_to_ternary("19")
	end

	def test_convert_number
		assert_equal "", @convertor.convert_number("")
		assert_equal 11, @machine.numeric_resolve(@convertor.convert_number("t102"))
		[ 0, 10, 100, 1000, 10000 ].each { |n|
			result = @convertor.convert_number(n.to_s)
			check = @machine.numeric_resolve(result)
			assert_equal n, check
		}
	end

	def test_doesnt_change_labels
		program = @convertor.convert("LABEL 10000\nGOTO 10000")
		assert program =~ /\Al([a-l]+) g([a-l]+)\Z/
		assert $1 == $2
	end

	def test_convert_argument
		assert_equal "", @convertor.convert_arguments("")
		assert_equal "l", @convertor.convert_arguments("$")

		for n in [ 1000, 10, 0, 20, 60, 80 ]
			out = @convertor.convert_arguments("$$#{n}")
			assert out =~ /\All(.+)\Z/
			assert_equal n, @machine.numeric_resolve($1)
		end
	end

	def test_convert
		assert_equal "a b c", @convertor.convert(<<END)
	load
	# Hello World
	set
	plus // Hello World
END
	end

	def test_convert_line
		assert_equal "il", @convertor.convert_line("OUT *")
	end
end
