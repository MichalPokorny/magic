#!/usr/bin/ruby -w
$: << '.'
require_relative 'sms-interface'
require_relative 'tasks'

tasks = {
	"100" => SMSInterface::Task.new(TaskOutputConstant.new(9), 10),
	"101" => SMSInterface::Task.new(TaskPrint1Through100.new, 7),
}

# TODO: test partial score (like 3 out of 7 tests failing)

robot = SMSInterface.new(tasks)
puts robot.interact(STDIN.read)
