require_relative "spec_helper"

describe 'Gemspec' do
  it 'should have the right license' do
    config = YAML.load_file(File.expand_path("#{File.dirname(__FILE__)}/../config.yml"))

    expect(config).to have_key("license")
    expect(config["license"].downcase).not_to include("gpl")
    expect(config["license"].downcase).not_to include("gnu")
  end
end