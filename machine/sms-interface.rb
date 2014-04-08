$: << '.'
require_relative 'machine'

class SMSInterface
	class Task
		def initialize(task, points)
			@task = task
			@points = points
		end

		attr_reader :points

		def get_results(program)
			results = @task.get_results(program)

			# Calculate points with 2 digits of precision.
			[ ((results.count(::Task::Result::OK)).to_f / results.size * points).round(2), results ]
		end

		def correct_solution?(program)
			@task.correct_solution?(program)
		end
	end
	# Tasks should be an array or hash of SMSInterface::Task-s.
	# Tasks will be identified by an index in @tasks.
	def initialize(tasks)
		@tasks = tasks
	end

	def points_text(n)
		n = n.round
		case n
		when 0 then '0 bodu' # '0 bodů'
		when 1 then '1 bod'
		when 2..4 then "#{n} body"
		else "#{n} bodu" # "#{n} bodů"
		end
	end

	# MESSAGES = {
	# 	no_source: "CHYBA: žádný zdrojový kód.",
	# 	invalid_chars: "CHYBA: zdrojový kód obsahuje neplatné znaky. Povolená jsou písmena A-K nebo a-k a mezery.",
	# 	no_such_task: "CHYBA: neznámá úloha %{task_id}.",
	#		wrong_input_format: "CHYBA: špatný formát vstupu. Očekávám: (cislo ulohy) (zdrojovy kod) - například '21 acde kkab'",
	# 	congratulations: "Gratuluji! Řešení je správně a za %{points}.",
	# 	partial_solution: "Bohužel, některé testy neprošly (%{test_results}). Řešení je za %{points}."
	# }

	MESSAGES = {
		no_source: "CHYBA: zadny zdrojovy kod.",
		invalid_chars: "CHYBA: zdrojovy kod obsahuje neplatne znaky. Povolena jsou jenom pismena A-L nebo a-l a mezery.",
		no_such_task: "CHYBA: neznama uloha %{task_id}.",
		wrong_input_format: "CHYBA: spatny format vstupu. Ocekavam: (cislo ulohy) (zdrojovy kod) - napriklad '21 acde kkab'",
		congratulations: "Gratuluji! Reseni je spravne a za %{points}.",
		partial_solution: "Bohuzel, nektere testy neprosly (%{test_results}). Reseni je za %{points}."
	}

	def get_reply(task_id, source)
		source.strip!
		return MESSAGES[:no_source] unless source.length > 0
		return MESSAGES[:invalid_chars] unless source =~ /\A(([a-lA-L]|\W)+)\Z/

		task = @tasks[task_id]
		return MESSAGES[:no_such_task] % { task_id: task_id } unless task

		return MESSAGES[:congratulations] % { points: points_text(task.points) } if task.correct_solution?(source)
		pp task.get_results(source)
		points, results = task.get_results(source)

		MESSAGES[:partial_solution] % { test_results: results.join(','), points: points_text(points) }
	end

	# Expected input format:
	#		(task number)	(source code)
	#
	# Should return a reasonably short message.
	def interact(input)
		input.strip!
		return MESSAGES[:wrong_input_format] unless input =~ /\A(\d+)\W+(([a-lA-L]|\W)+)\Z/
		get_reply($1, $2)
	end
end
