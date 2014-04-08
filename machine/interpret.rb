#!/usr/bin/ruby -w
$: << '.'
require_relative 'machine'

print "Zdrojak? (pismenne zapisy instrukci oddelene mezerami) "
zdrojak = gets
print "Vstup? (cisla oddelena mezerami) "
vstup = (gets || '').split(/[^0-9]+/).map(&:to_i)

machine = Machine.new
machine.input = vstup
machine.run_program zdrojak
puts "Vystup: #{machine.output.join(', ')}"
