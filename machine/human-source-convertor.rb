# Syntax:
#   (instruction) (args) // comment # another comment
#
#   instruction: get, set, etc. - see HumanSourceConvertor::INSTRUCTIONS
#   args:
#						* or $ for indirection
#						"T(\d+)" for ternary number
#						"(\d+)" for decimal number
#
#						Examples: *T10, $987, 5, empty string

class HumanSourceConvertor
	# Strips C and Bash comments
	def strip_line_comments(line)
		return strip_line_comments($1) if line =~ /\A(.*)(#|\/\/)/
		line
	end

	def decimal_to_ternary(decimal)
		n = decimal.to_i
		return "0" if n == 0 # special case
		result = ""
		while n > 0
			result << (n % 3).to_s
			n /= 3
		end
		result.reverse
	end

	def ternary_char(value, randomize: true, first: true)
		choose = [%w{a b c}]
		if randomize
			choose += [%w{d e f}, %w{g h i}]
			unless first
				choose << %w{j k l} unless first # Indirekce se nesmi vyskytnout jako prvni
			end
		end
		choose[rand(choose.length)][value]
	end

	def convert_number(args, randomize: true)
		return "" if args.empty?

		# Ternary number
		if args =~ /\A(T|t)(.+)\Z/
			return (0...$2.chars.length).map { |i|
				char = $2.chars[i]
				ternary_char(char.to_i, randomize: randomize, first: i == 0)
			}.join
		end

		# Decimal number
		num = decimal_to_ternary(args)
		(0...num.chars.length).map { |i|
			char = num.chars[i]
			ternary_char(char.to_i, randomize: randomize, first: i == 0)
		}.join
	end

	def convert_arguments(args, randomize: true)
		result = ""
		while args.start_with?('$') || args.start_with?('*')
			result << 'l'
			args = args[1...args.length]
		end

		result += convert_number(args, randomize: randomize)

		result
	end

	INSTRUCTIONS = {
		a: %w{get load},
		b: %w{set put},
		c: %w{plus},
		d: %w{minus},
		e: %w{and},
		f: %w{or},
		g: %w{goto},
		h: %w{read input in},
		i: %w{write output out},
		j: %w{if},
		k: %w{xor},
		l: %w{label}
	}

	def convert_line(line)
		line.downcase!

		opcodes_to_instructions = {}
		INSTRUCTIONS.each { |instruction, opcodes|
			opcodes.each { |opcode|
				opcodes_to_instructions[opcode] = instruction
			}
		}

		raise "invalid line: #{line}" unless line =~ /\A([a-z]+)[ \t\n\r]*((\$|\*)*t?[0-9]*)\Z/
		instruction = opcodes_to_instructions[$1]
		args = $2

		raise unless instruction

		instruction.to_s + convert_arguments(args, randomize: !%w{g l}.include?(instruction.to_s))
	end

	def convert(source)
		# Strip every line, skip comments.
		lines = source.lines.map { |line|
			strip_line_comments(line)
		}.map(&:strip).select { |line| !line.empty? }

		lines.map { |line|
			convert_line(line)
		}.join(" ")
	end
end
