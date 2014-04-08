require 'sinatra'
require 'haml'

$: << '../machine'
require 'machine'
require 'tasks'
require 'sms-interface'

include Tasks

tasks = {
	"79987" => SMSInterface::Task.new(OutputEternal.new(9), 3),
	"73288" => SMSInterface::Task.new(Primes.new, 12),
	"13738" => SMSInterface::Task.new(Div3.new, 15), # delba koristi, stanoviste 1
	"48069" => SMSInterface::Task.new(BitMirror.new, 16),
	"53609" => SMSInterface::Task.new(Print_0_1_3_7_15.new, 4), # dira v zemi
	"27613" => SMSInterface::Task.new(Print1Through100.new, 8),
	"61327" => SMSInterface::Task.new(PrintPi.new, 9),
	"58978" => SMSInterface::Task.new(MaxOfThree.new, 10),
	"47501" => SMSInterface::Task.new(Modulo.new, 11), # stanoviste 4
	"84767" => SMSInterface::Task.new(GCD.new, 10),

	# Testovaci ukol
	"11111" => SMSInterface::Task.new(Fibonacci.new, 10000)

	# Nevybrane ulohy
	#"" => SMSInterface::Task.new(Fibonacci.new, 10),
	#"" => SMSInterface::Task.new(Print_1_3_2_4.new, 10),
	#"87549" => SMSInterface::Task.new(IsPrime.new, 10),
	#"61327" => SMSInterface::Task.new(LeastUnused10.new, 10),
	#"" => SMSInterface::Task.new(Print_1_1_2_1_2_3.new, 10),
	#"" => SMSInterface::Task.new(Invert5.new, 10),
}

#fail if tasks.size != 10
robot = SMSInterface.new(tasks)

get '/sms-handler' do
	sender, identifier, text, smsid, time = params.values_at(:sender, :identifier, :text, :smsid, :time)

	unless sender && identifier && text && smsid
		# return "CHYBA API: nedostal jsem dost parametrů. Zavolej orgům."
		STDERR.puts "CHYBA API: Nedostal jsem dost parametru. Dostal jsem tyhle: #{params.inspect}"
		return "CHYBA API: nedostal jsem dost parametru. Zavolej orgum."
	end

	STDERR.puts "Prisla SMS od #{sender}, uloha #{identifier}."
	STDERR.puts "Text: #{text}"

	reply = robot.get_reply(identifier, text)

	STDERR.puts "Odpovidam: #{reply}"

	reply
end

get '/' do
	reply = nil
	if params[:code]
		STDERR.puts "Poslane reseni #{params[:code]}: #{params[:source]}"
		reply = robot.get_reply(params[:code], params[:source])
	end

	custom_reply = nil
	custom_code = nil
	custom_limit = 10_000
	if params[:custom_code]
		custom_reply = []

		code = params[:custom_code].downcase
		nums = (params[:custom_input] || "").split
		input = []

		unless nums.all? { |x| x =~ /\A\d+\Z/ }
			custom_reply << "Format vstupu pro stroj je spatny, maji to byt cisla oddelena mezerou. Pouzivam misto toho prazdny vstup."
		else
			input = nums.map(&:to_i)
			unless input.all? { |x| x >= 0 && x < 256 }
				custom_reply << "Na vstupu jsou cisla mensi nez 0 nebo vetsi nez 256. Modulim to 256."
			end
			input = input.map { |x| x % 256 }
		end

		unless code =~ /\A[a-l \t\n\r]*\Z/
			custom_reply << "Zdrojak je ve spatnem formatu... :("
		end

		custom_limit = params[:custom_limit].to_i || 10_000
		if custom_limit == 0
			custom_reply << "Program by asi mel bezet dele nez 0 instrukci. Necham ho bezet 100 kroku."
			custom_limit = 100
		end

		if custom_limit > 10_000
			custom_reply << "Takhle dlouho program bezet nemuze. Necham ho bezet jenom 10 000 kroku."
			custom_limit = 10_000
		end

		machine = Machine.new
		machine.input = input
		begin
			STDERR.puts "Poustim #{code}, limit: #{custom_limit}"
			machine.run_program(code, time: custom_limit)
		rescue Machine::ExecutionTimeout
			STDERR.puts "Dosel cas."
			custom_reply << "Programu dosel cas (#{custom_limit} instrukci)."
		rescue Machine::InvalidInstruction
			STDERR.puts "Spatna instrukce."
			custom_reply << "Program umrel na spatnou instrukci."
		rescue Machine::OutOfInput
			STDERR.puts "Dosel vstup."
			custom_reply << "Program umrel na konec vstupu."
		end

		output = machine.output.map(&:to_s).join(', ')
		if output.empty?
			custom_reply << "Program nic nevypsal."
		else
			custom_reply << "Program vypsal: #{machine.output.map(&:to_s).join(', ')}."
		end

		custom_reply = custom_reply.join "\n"

		custom_code = code
	end

	haml :index, locals: { reply: reply, code: params[:code], source: params[:source], custom_code: custom_code, custom_reply: custom_reply, custom_input: params[:custom_input], custom_limit: custom_limit }
end
