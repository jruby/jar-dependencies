# frozen_string_literal: true

# this file is maven DSL and used by maven via jars/maven_exec.rb

def eval_file(file)
  file = File.join(__dir__, file)
  eval(File.read(file), nil, file) # rubocop:disable Security/Eval
end

eval_file('attach_jars_pom.rb')
eval_file('output_jars_pom.rb')
