require "yaml"

config = YAML.load_file(File.join(File.dirname(__FILE__), "config.yml"))

Gem::Specification.new do |s|
  s.name          = File.basename(File.expand_path(File.dirname(__FILE__)))
  s.version       = config["version"]
  s.platform      = Gem::Platform::RUBY
  s.license       = "GNU General Public License v2.0"
  s.authors       = [config["author"]]
  s.email         = config["email"]
  s.homepage      = config["homepage"]
  s.summary       = config["summary"]
  s.description   = config["description"]

  s.add_runtime_dependency "brpm_content", ">=0.1.10"

  if config["dependencies"]
    config["dependencies"].each do |dependency|
      if dependency.is_a?(Hash)
        modul = dependency.keys[0]
        options = dependency.values[0]
      else
        modul = dependency
        options = {}
      end
      s.add_runtime_dependency modul, options["version"] unless ["brpm", "bladelogic", "jira"].include?(modul)
    end
  end

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"

  s.files         = `git ls-files`.split("\n")
  s.require_path  = 'lib'
end
