class Machine
	class ExecutionError < StandardError; end
	class ExecutionTimeout < ExecutionError; end
	class InvalidInstruction < ExecutionError; end
	class OutOfInput < ExecutionError; end

	class Memory
		SIZE = 256
		CELL_MAX = 256

		def initialize
			reset
		end

		def reset(reset_to = 0)
			@contents = [reset_to] * SIZE
		end

		def [](i)
			a = @contents[i % SIZE]
#			puts "MEM[#{i}] = #{a}"
			a
		end

		def []=(i, arg)
#			puts "MEM[#{i}] <- #{arg}"
			@contents[i % SIZE] = arg % CELL_MAX;
		end

		def set_contents(c)
			raise unless c.count == SIZE
			@contents = c.dup
		end
	end

	def initialize
		@memory = Memory.new
		@instruction_limit = 1_000_000
		@overflow = nil # No overflow so far.

		@pi = File.open(File.join(File.dirname(__FILE__), "pi"), "r") do |f|
			f.read.chars.map(&:to_i)[0...Memory::SIZE]
		end
	end

	private
	def reset_output
		@output = []
	end

	public

	attr_accessor :instruction_limit

	attr_reader :output
	attr_reader :memory

	def instruction_to_ternary(i)
		str = "abcdefghijkl".chars
		raise InvalidInstruction, "Cannot convert #{i} to ternary on position #@pc" unless str.include? i
		str.index(i) % 3
	end

	def numeric_resolve(instructions)
		# just ternary
		n = 0
		for i in instructions.chars
			n = (n * 3) + instruction_to_ternary(i)
		end
		n
	end

	def resolve(instructions)
		result =
			if instructions.nil? || instructions.empty?
				42
			elsif instructions[0] == 'l' # "label"
				i = resolve(instructions[1...instructions.length])
				debug "memory at #{i}: #{memory[i]}"
				memory[i]
			else
				numeric_resolve(instructions)
			end

		debug "resolved #{instructions} to #{result}"

		result
	end

	def w; memory[42]; end
	def w=(i); memory[42] = i; end

	def interpret(instruction, args)
		debug "running #{instruction} on <#{args}>"

		if args =~ /([^a-l])/
			raise InvalidInstruction, "Invalid instruction '#$1' in arguments on position #@pc"
		end

		a = resolve(args)

		case instruction
		when 'a' # get
			self.w = a
			debug "[42] <= #{a}"
		when 'b'
			memory[a] = w
			debug "[#{a}] <= [42] (currently #{w})"
		when 'c'
			@overflow = (self.w + a >= Memory::CELL_MAX)
			self.w += a
			debug "[42] += #{a} (result: #{w}, overflow: #@overflow)"
		when 'd'
			@overflow = (self.w < a)
			self.w -= a
			debug "[42] -= #{a} (result: #{w}, overflow: #@overflow)"
		when 'e'
			debug "[42] &= #{a}"
			self.w &= a
		when 'f'
			if args.empty?
				if @overflow.nil?
					debug "Filling with pi"
					# Super specialni pripad: zaplni pamet cislem pi :)
					memory.set_contents @pi
				else
					debug "[42] <= overflow? (#{@overflow})"
					self.w = @overflow ? 1 : 0
				end
			else
				debug "[42] |= #{a}"
				self.w |= a
			end
		when 'g'
			# case 1
			search = 'l' + args
			index = @instructions.index(search)
			unless index.nil?
				debug "goto: found #{search} on #{index}"
				@pc = index
			else
				# case 2
				index = resolve(args) - 1
				if index < @instructions.count
					debug "goto: going to #{index}"
					@pc = index
				else
					debug "goto: special case"
					# case 3
					memory.reset 42
					@pc = 0
				end
			end
		when 'h'
			addr = resolve(args)
			val = do_input
			debug "[#{addr}] <= (input) #{val}"
			memory[addr] = val
		when 'i'
			do_output(resolve(args))
		when 'j'
			if @pc == @instructions.count
				# specialni pripad IFu na konci programu
				return interpret('g', 'l' + args)
			end

			if memory[a] == 0
				debug "skipping, [#{a}], which is #{memory[a]} == 0"
				@pc += 1
			end
		when 'k'
			self.w ^= a
		when 'l'
			# label, nop.
		else
			p @instructions
			raise InvalidInstruction, "Unhandled instruction '#{instruction}' on position #@pc"
		end
		@pc += 1
	end

	def do_output(what)
		puts "output: #{what}" if DEBUG
		@output << what
	end

	def input=(x)
		@input = x.dup
	end

	def do_input
		if @input.empty?
			raise OutOfInput, "Ran out of input."
		else
			@input.shift
		end
	end

	def debug(*args)
		if DEBUG
			puts(*args)
		end
	end

	DEBUG = false

	def run_program(source_code, time: nil, output_limit: 100)
		reset_output
		@memory.reset

		# Strip comments
		source_code = source_code.each_line.select { |l| ! l.strip.start_with?('#') }.join

		instructions = source_code.split(/\s+/).select { |i| !i.empty? }.map(&:downcase)
		@pc = 1
		ic = 0
		@instructions = instructions

		if instructions.empty?
			# Hmm...
			return []
		end

		loop do
			i = instructions[@pc - 1]
			interpret(i[0], i[1...i.length])
			ic += 1

			break if @pc > instructions.count

			sleep 0.01 if DEBUG
			puts if DEBUG

			break if time && ic >= time
			raise ExecutionTimeout if ic >= @instruction_limit
			
			# XXX: We are now hoping that we will never need a bigger output.
			break if output.size >= output_limit # TODO: use this in places...

		end

		output
	end
end
