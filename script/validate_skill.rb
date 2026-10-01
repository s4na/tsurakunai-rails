# frozen_string_literal: true

require "yaml"

root = File.expand_path("../skills/tsurakunai-rails", __dir__)
source = File.read(File.join(root, "SKILL.md"))
frontmatter = source.match(/\A---\r?\n(.*?)\r?\n---\r?\n/m)
raise "Missing skill frontmatter" unless frontmatter

metadata = YAML.safe_load(frontmatter[1])
raise "Skill name does not match installation directory" unless metadata.fetch("name") == File.basename(root)
raise "Missing skill description" unless metadata.fetch("description").is_a?(String) && !metadata["description"].empty?

# Validate relative references which travel with the installed package.
source.scan(/\]\((references\/[^)]+)\)/).flatten.each do |reference|
  path = File.expand_path(reference, root)
  raise "Invalid or missing reference: #{reference}" unless path.start_with?("#{root}/") && File.file?(path)
end
ui = YAML.safe_load_file(File.join(root, "agents", "openai.yaml")).fetch("interface")
%w[display_name short_description default_prompt].each do |field|
  raise "Missing UI metadata: #{field}" unless ui.fetch(field).is_a?(String) && !ui[field].empty?
end
raise "Missing skill invocation in default prompt" unless ui.fetch("default_prompt").include?("$#{metadata.fetch('name')}")

puts "Skill metadata and packaged references validated."
