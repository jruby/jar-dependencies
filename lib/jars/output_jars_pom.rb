# frozen_string_literal: true

# this file is maven DSL

if ENV_JAVA['jars.quiet'] != 'true'
  model.dependencies.each do |d|
    puts "      #{d.group_id}:#{d.artifact_id}" \
         "#{":#{d.classifier}" if d.classifier}" \
         ":#{d.version}:#{d.scope || 'compile'}"
    next if d.exclusions.empty?

    puts "          exclusions: #{d.exclusions.collect do |e|
      "#{e.group_id}:#{e.artifact_id}"
    end.join}"
  end
end
