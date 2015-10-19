require 'fileutils'
require "brpm_script_executor"

def setup_brpm_auto
  FileUtils.mkdir_p "/tmp/brpm_content"

  BrpmAuto.setup(get_default_params)

  BrpmAuto.require_module "brpm_module_brpm"

  @brpm_rest_client = BrpmRestClient.new('http://brpm-content.pulsar-it.be:8088/brpm', ENV["BRPM_API_TOKEN"])
end

def get_default_params
  params = {}
  params['also_log_to_console'] = 'true'

  params['brpm_url'] = 'http://brpm-content.pulsar-it.be:8088/brpm'
  params['brpm_api_token'] = ENV["BRPM_API_TOKEN"]

  params['output_dir'] = "/tmp/brpm_content"

  params
end

def cleanup_request_params
  request_params_file = "/tmp/brpm_content/request_data.json"
  File.delete(request_params_file) if File.exist?(request_params_file)
end

def set_request_params(request_params)
  request_params_file = File.new("/tmp/brpm_content/request_data.json", "w")
  request_params_file.puts(request_params.to_json)
  request_params_file.close
end

def cleanup_requests_and_plans_for_app(app_name)
  app = @brpm_rest_client.get_app_by_name(app_name)

  requests = @brpm_rest_client.get_requests_by({ "app_id" => app["id"]})

  requests.each do |request|
    @brpm_rest_client.delete_request(request["id"]) unless request.has_key?("request_template")
  end

  plan_template = @brpm_rest_client.get_plan_template_by_name("#{app_name} Release Plan")

  plans = @brpm_rest_client.get_plans_by({ "plan_template_id" => plan_template["id"]})
  plans.each do |plan|
    @brpm_rest_client.cancel_plan(plan["id"])
    @brpm_rest_client.delete_plan(plan["id"])
  end
end

def cleanup_version_tags_for_app(app_name)
  app = @brpm_rest_client.get_app_by_name(app_name)

  version_tags = @brpm_rest_client.get_version_tags_by({ "app_id" => app["id"]})

  version_tags.each do |version_tag|
    @brpm_rest_client.delete_version_tag(version_tag["id"])
  end
end
