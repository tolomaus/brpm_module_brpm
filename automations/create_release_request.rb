# TODO workaround bug fix where the request params are not transferred to the updated application's directory
require 'fileutils'

brpm_rest_client = BrpmRestClient.new

BrpmAuto.log "Retrieving the application..."
application = brpm_rest_client.get_app_by_name(BrpmAuto.params["application_name"])
application_version = BrpmAuto.params["application_version"]

release_request_template_name = BrpmAuto.params["release_request_template_name"] || "Release application"
release_plan_template_name = BrpmAuto.params["release_plan_template_name"]
release_plan_name = BrpmAuto.params["release_plan_name"]

request_name = "Release #{application["name"]} #{application_version}"

request_params = {}
request_params["auto_created"] = true
request_params["application_version"] = application_version
request_params["component_versions"] = {}
request_params["component_versions"]["EF - .NET web front end"] = BrpmAuto.params["ef_net_version"]
request_params["component_versions"]["EF - Java calculation engine"] = BrpmAuto.params["ef_java_version"]

if release_plan_template_name or release_plan_name
  if release_plan_template_name
    BrpmAuto.log "Creating a new plan from template '#{release_plan_template_name}' for #{application["name"]} v#{application_version} ..."
    plan = brpm_rest_client.create_plan(release_plan_template_name, "Release #{BrpmAuto.params["application_name"]} v#{application_version}", Time.now)

    BrpmAuto.log "Planning the plan ..."
    brpm_rest_client.plan_plan(plan["id"])

    BrpmAuto.log "Starting the plan ..."
    brpm_rest_client.start_plan(plan["id"])
  elsif release_plan_name
    plan = brpm_rest_client.get_plan_by_name(release_plan_name)
    raise "Release plan '#{release_plan_name}' doesn't exist." unless plan
  end

  BrpmAuto.log "Creating a new request '#{request_name}' from template '#{release_request_template_name}' for application '#{application["name"]}' and plan #{plan["name"]}..."
  target_request = brpm_rest_client.create_request_for_plan_from_template(
      plan["id"],
      "Release",
      release_request_template_name,
      request_name,
      "release",
      false, # execute_now
      request_params
  )

else
  BrpmAuto.log "Creating a new request '#{request_name}' from template '#{release_request_template_name}' for application '#{application["name"]}'..."
  target_request = brpm_rest_client.create_request(
      release_request_template_name,
      request_name,
      "release",
      false, # execute_now
      request_params
  )
end

unless target_request["apps"].first["id"] == application["id"]
  BrpmAuto.log "The application from the template is different than the application we want to use so updating the request with the correct application..."
  request = {}
  request["id"] = target_request["id"]
  request["app_ids"] = [application["id"]]
  target_request = brpm_rest_client.update_request_from_hash(request)

  # TODO workaround bug fix where the request params are not transferred to the updated application's directory
  Dir.mkdir "#{BrpmAuto.params.automation_results_dir}/request/#{application["name"]}/#{1000 + target_request["id"].to_i}"
  json = FileUtils.mv("#{BrpmAuto.params.automation_results_dir}/request/#{target_request["apps"].first["name"]}/#{1000 + target_request["id"].to_i}/request_data.json", "#{BrpmAuto.params.automation_results_dir}/request/#{application["name"]}/#{1000 + target_request["id"].to_i}/request_data.json")

  BrpmAuto.log "Setting the owner of the manual steps to the groups that belong to application '#{application["name"]}'..."
  target_request["steps"].select{ |step| step["manual"] }.each do |step|
    BrpmAuto.log "Retrieving the details of step #{step["id"]} '#{step["name"]}'..."
    step_details = brpm_rest_client.get_step_by_id(step["id"])

    next if step_details["procedure"]

    group_name = "#{step_details["owner"]["name"]} - #{application["name"]}"

    BrpmAuto.log "Retrieving group #{group_name}..."
    group = brpm_rest_client.get_group_by_name(group_name)
    raise "Group '#{group_name}' doesn't exist" if group.nil?

    step_to_update = {}
    step_to_update["id"] = step["id"]
    step_to_update["owner_id"] = group["id"]
    step_to_update["owner_type"] = "Group"
    brpm_rest_client.update_step_from_hash step_to_update
  end
end

BrpmAuto.log "Planning the request ... "
brpm_rest_client.plan_request(target_request["id"])

BrpmAuto.log "Starting the request ... "
brpm_rest_client.start_request(target_request["id"])

BrpmAuto.params["result"] = {}
BrpmAuto.params["result"]["request_id"] = target_request["id"]

