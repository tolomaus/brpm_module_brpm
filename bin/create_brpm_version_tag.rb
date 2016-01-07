#!/usr/bin/env ruby
require "brpm_script_executor"

params = {}
params["application"] = ENV["APPLICATION"]
params["component"] = ENV["COMPONENT"]
params["component_version"] = ENV["COMPONENT_VERSION"]

params["brpm_url"] = "http://#{ENV["BRPM_HOST"]}:#{ENV["BRPM_PORT"]}/brpm"
params["brpm_api_token"] = ENV["BRPM_TOKEN"]

params["log_file"] = ENV["LOG_FILE"]
params["also_log_to_console"] = "true"

BrpmScriptExecutor.execute_automation_script("brpm_module_brpm", "create_version_tag", params)

