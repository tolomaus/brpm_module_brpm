require "yaml"

config = YAML.load_file(File.join(File.dirname(__FILE__), "config.yml"))

Gem::Specification.new do |spec|
  spec.name          = File.basename(File.expand_path(File.dirname(__FILE__)))
  spec.version       = config["version"]
  spec.platform      = Gem::Platform::RUBY
  spec.license       = "GNU General Public License v2.0"
  spec.authors       = [config["author"]]
  spec.email         = config["email"]
  spec.homepage      = config["homepage"]
  spec.summary       = config["summary"]
  spec.description   = config["description"]

  spec.add_runtime_dependency "brpm_content", ">=0.1.11"

  if config["dependencies"]
    config["dependencies"].each do |dependency|
      if dependency.is_a?(Hash)
        modul = dependency.keys[0]
        options = dependency.values[0]
      else
        modul = dependency
        options = {}
      end
      spec.add_runtime_dependency modul, options["version"] unless ["brpm", "bladelogic", "jira"].include?(modul)
    end
  end

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"

  spec.files         = `git ls-files`.split("\n")
  spec.require_path  = 'lib'

  spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  spec.bindir        = "bin"
end
