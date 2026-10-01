# frozen_string_literal: true

require "yaml"

# Optional root lets package smoke validate the installed, portable skill set.
root = File.expand_path(ARGV.fetch(0, "../skills"), ARGV.empty? ? __dir__ : Dir.pwd)
names = %w[tsurakunai-rails tsurakunai-rails-implement tsurakunai-rails-review]
names.each do |name|
  directory = File.join(root, name)
  source = File.read(File.join(directory, "SKILL.md"))
  frontmatter = source.match(/\A---\r?\n(.*?)\r?\n---\r?\n/m)
  raise "Missing skill frontmatter: #{name}" unless frontmatter

  metadata = YAML.safe_load(frontmatter[1])
  raise "Skill name does not match installation directory: #{name}" unless metadata.fetch("name") == name
  raise "Missing skill description: #{name}" unless metadata.fetch("description").is_a?(String) && !metadata["description"].empty?

  ui = YAML.safe_load_file(File.join(directory, "agents", "openai.yaml")).fetch("interface")
  %w[display_name short_description default_prompt].each do |field|
    raise "Missing UI metadata: #{name}/#{field}" unless ui.fetch(field).is_a?(String) && !ui[field].empty?
  end
  raise "Missing skill invocation: #{name}" unless ui.fetch("default_prompt").include?("$#{name}")

  # Shared references and sibling workflows must remain inside the installed set.
  Dir[File.join(directory, "**", "*.md")].each do |document|
    File.read(document).scan(/\]\(([^)]+)\)/).flatten.each do |reference|
      next if reference.match?(/\A(?:[a-z]+:|#)/i)

      path = File.expand_path(reference.split("#").first, File.dirname(document))
      raise "Invalid or missing reference: #{document}: #{reference}" unless path.start_with?("#{root}/") && File.file?(path)
    end
  end
end

puts "Three skill entry points, metadata and shared references validated."
