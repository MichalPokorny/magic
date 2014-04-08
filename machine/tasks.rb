$: << '.'
require_relative 'machine'
require 'pp'

class Task
	def correct_solution?(program)
		raise "not implemented"
	end

	# TODO: insert instruction count limits into spec

	module Result
		WRONG_ANSWER = 'WA'
		OK = 'OK'
		TIMEOUT = 'TO'
		INVALID_INSTRUCTION = 'IN'
		OUT_OF_INPUT = 'OI'
	end

	class Standard < Task
		class AbstractTest
			protected
			def run_wrapped(&block)
				begin
					block.call
				rescue Machine::ExecutionTimeout
					Result::TIMEOUT
				rescue Machine::InvalidInstruction
					Result::INVALID_INSTRUCTION
				rescue Machine::OutOfInput
					Result::OUT_OF_INPUT
				end
			end

			public
			def self.create(cases)
				result = []
				cases.each do |input, output|
					if output.is_a?(Hash)
						result << new(input, output[:output], output[:instruction_limit] || 100_000)
					else
						if output.respond_to?(:to_a)
							output = output.to_a
						end

						if output.is_a?(Array)
							result << self.new(input, output)
						else raise ArgumentError, "output must be an array, not #{output.class.name}" end
					end
				end
				result
			end
		end

		# Tests "input => output"
		class Test < AbstractTest
			attr_accessor :instruction_limit
			attr_accessor :input, :output
			def initialize(input, output, instruction_limit = 100_000)
				@input = input; @output = output; @instruction_limit = instruction_limit
			end

			def get_result(program)
				machine = Machine.new
				machine.instruction_limit = instruction_limit
				machine.input = input
				run_wrapped do
					if machine.run_program(program, output_limit: output.length + 1) == output
						Result::OK
					else
						Result::WRONG_ANSWER
					end
				end
			end
		end

		# Tests "input => output prefix"
		class PrefixTest < AbstractTest
			attr_accessor :instruction_limit
			attr_accessor :input, :output_prefix

			def initialize(input, output_prefix, instruction_limit: 100_000)
				@input = input; @output_prefix = output_prefix; @instruction_limit = instruction_limit
			end

			def get_result(program)
				machine = Machine.new
				machine.instruction_limit = instruction_limit
				machine.input = input
				run_wrapped do
					result = nil

					begin
						machine.run_program(program, output_limit: output_prefix.length)
					rescue Machine::ExecutionTimeout
						result = Result::TIMEOUT
					end

					unless result
						result = if machine.output[0...output_prefix.length] == output_prefix
							Result::OK
						else
							Result::WRONG_ANSWER
						end
					end

					result
				end
			end
		end

		def tests
			raise "not implemented"
		end

		# Returns test results.
		def get_results(program)
			# TODO: better with map...
			tests.map { |test| test.get_result(program) }
		end

		def correct_solution?(program)
			tests.all? { |test|
				test.get_result(program) == Result::OK
			}
		end

		attr_reader :error
	end
end

module Tasks; end

# Some basic tasks
class Tasks::OutputConstant < Task::Standard
	def initialize(const = 10)
		@const = const
	end
	
	def tests
		Test.create({
			[] => { output: [ @const ], instruction_limit: 1_000 },
			(1..5).to_a => { output: [ @const ], instruction_limit: 1_000 }
		})
	end
end

class Tasks::OutputEternal < Task::Standard
	def initialize(const = 10)
		@const = const
	end
	
	def tests
		[ 1, 5, 10, 30 ].map { |i|
			PrefixTest.new([], [@const] * i, instruction_limit: 1_000 )
		} << PrefixTest.new([1,2,3], [@const] * 10, instruction_limit: 1_000)
	end
end

class Tasks::Print1Through100 < Task::Standard
	def tests
		# Give a few points for a partial solution
		Test.create({
			[] => (1..100)
		}) + PrefixTest.create({
			[] => (1..10),
			[] => (1..50)
		})
	end
end

# TODO test
class Tasks::MaxOfThree < Task::Standard
	def tests
		Test.create({
			[1, 2, 3] => [3],
			[1, 3, 2] => [3],
			[3, 2, 1] => [3],
			[10, 20, 30] => [30],
			[30, 30, 30] => [30],
			[30, 100, 200] => [200]
		})
	end
end

# TODO test
class Tasks::Fibonacci < Task::Standard
	def tests
		fibs = [0, 1]
		while fibs[-1] < 256
			fibs << fibs[-1] + fibs[-2]
		end
		fibs.pop

		hash = {}
		fibs.each_index { |i|
			hash[[i]] = [fibs[i]]
		}
		Test.create(hash)
	end
end

# TODO test
class Tasks::Sqrt < Task::Standard
	def tests
		hash = {}
		for i in [0, 1, 100, 200, 241]
			hash[[i]] = [Math.sqrt(i).floor]
		end
		Test.create(hash)
	end
end

# TODO test
class Tasks::Modulo < Task::Standard
	def tests
		inps = [
			[10, 3], [100, 17], [224, 88], [191, 2], [100, 101], [50, 50]
		]
		hash = {}
		for i in inps
			hash[i] = [i.first % i.last]
		end
		Test.create(hash)
	end
end

# TODO test
class Tasks::GCD < Task::Standard
	def tests
		inps = [
			[170, 30], [81, 27], [243, 170],
			[17, 19], [37, 11], [60, 200]
			# times out: [65535, 65534]
		]
		hash = {}
		for i in inps
			hash[i] = [i.first.gcd(i.last)]
		end
		Test.create(hash)
	end
end

# TODO test
class Tasks::Print_1_3_2_4 < Task::Standard
	def tests
		PrefixTest.create({
			[] => [1, 3, 2, 4, 3, 5, 4, 6],
			[1, 2, 3, 4, 5] => [1, 3, 2, 4, 3, 5, 4, 6]
		})
	end
end

# TODO test
class Tasks::Print_0_1_3_7_15 < Task::Standard
	def tests
		PrefixTest.create({
			[] => [0, 1, 3, 7, 15, 31, 63, 127],
			[1, 2, 3, 4, 5] => [0, 1, 3, 7, 15, 31, 63, 127]
		})
	end
end

# TODO test
class Tasks::IsPrime < Task::Standard
	def tests
		primes = [17, 19, 23, 41] # 65521 is a prime, but it's too slow in our solution.
		nonprimes = [0, 1, 200, 100, 155]
		hash = {}
		primes.each { |i| hash[[i]] = [1] }
		nonprimes.each { |i| hash[[i]] = [0] }
		Test.create(hash)
	end
end

# TODO test
class Tasks::Primes < Task::Standard
	def tests
		primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41]
		[3, 10, primes.length].map { |i|
			PrefixTest.new([], primes[0...i], instruction_limit: 1_000_000)
		}
	end
end

# TODO test
class Tasks::PrintPi < Task::Standard
	def tests
		pi = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7]
		[ PrefixTest.new([], pi[0..5]), PrefixTest.new([], pi) ]
	end
end

class Tasks::Print_1_1_2_1_2_3 < Task::Standard
	def tests
		ary = []
		for i in 1..9
			for j in 1..i
				ary << j
			end
		end

		[5, 10, 20, ary.length].map { |k|
			PrefixTest.new([], ary[0...k])
		}
	end
end

class Tasks::Div3 < Task::Standard
	def tests
		nums = [0, 10, 100, 100, 200, 255, 31, 52]
		nums.map { |n|
			Test.new([n], [(n/3.0).ceil])
		}
	end
end

class Tasks::LeastUnused10 < Task::Standard
	def expected_output(input)
		used = [false] * 11
		for i in input
			used[i] = true
		end

		for i in 0..10
			return i unless used[i]
		end

		fail
	end

	def tests
		rnd = Random.new(10)

		(0...10).map {
			ary = (0...10).map { rnd.rand 11 }
			exp = [expected_output(ary)]
			Test.new(ary, exp)
		}
	end
end

class Tasks::Invert5 < Task::Standard
	def tests
		Test.create({
			[0, 0, 0, 0, 0] => [1, 1, 1, 1, 1],
			[1, 1, 0, 0, 1] => [0, 0, 1, 1, 0],
			[0, 0, 1, 1, 0] => [1, 1, 0, 0, 1],
			[0, 0, 1, 0, 0] => [1, 1, 0, 1, 1],
		})
	end
end

class Tasks::BitMirror < Task::Standard
	def tests
		Test.create({
			[0b0000_0000] => [0b0000_0000],
			[0b0000_0000] => [0b0000_0000],
			[0b0100_1000] => [0b0001_0010],
			[0b0100_1000] => [0b0001_0010],
			[0b1000_0001] => [0b1000_0001],
		})
	end
end
