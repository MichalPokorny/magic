#!/usr/bin/ruby -w

ENV['RACK_ENV'] = 'test'

$: << '.'
require 'app'
require 'rack/test'
require 'test/unit'
require 'webrat'

$: << '../machine'
require 'human-source-convertor'

Webrat.configure do |config|
	config.mode = :rack
end

class AppTest < Test::Unit::TestCase
	include Rack::Test::Methods
	include Webrat::Methods
	include Webrat::Matchers

	def app
		Sinatra::Application.new
	end

	def test_works_on_pi
		# 79987 checks for "outputs 5". Incidentally, 5 is the 5th digit of pi (4th
		# index).
		#
		# Source:
		#		(fill with PI) (OUT *5)
		run_code '79987', 'f ilbc g'
		assert_contain 'Gratuluji! Reseni je spravne a za 3 body.'
	end

	def run_code(id, code)
		visit '/sms-handler', :get, sender: "720123123", identifier: id, text: code,
			time: '20000101T1234000', smsid: 123
	end

	def test_sms_interface
		run_code '79987', 'ibaa g'
		assert_contain "Reseni je spravne"
	end
	
	def test_runs_custom_programs
		visit '/', :get, custom_code: 'f ilbe'
		assert_contain 'Program vypsal: 5.'

		visit '/', :get, custom_code: 'f ilbe', custom_limit: "ahoj svete"
		assert_contain 'Program vypsal: 5.'
	end

	def test_partial_solutions
		run_code '79987', 'ibaa ibaa'
		assert_contain "Bohuzel, nektere testy neprosly"
		assert_contain "OK"
		assert_contain "WA"
	end

	def test_accepts_good_solutions
		solutions = {
			79987 => "19-nine-generator",
			73288 => "18-primes",
			13738 => "22-div-3",
			48069 => "99-bitove-zrcadleni",
			53609 => "17-0-1-3-7-15-etc",
			27613 => "01-print-1-to-100",
			61327 => "20-pi",
			58978 => "02-max-of-three",
			47501 => "11-modulo",
			84767 => "12-gcd"
		}
		convertor = HumanSourceConvertor.new
		solutions.each do |k, v|
			code = convertor.convert(IO.read("../reseni/#{v}"))
			# puts "#{k}: correct solution should be #{code}"
			run_code k.to_s, code
			assert_contain 'Gratuluji! Reseni je spravne'
		end
	end
end
