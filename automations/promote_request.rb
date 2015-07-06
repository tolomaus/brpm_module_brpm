def get_source_requests(params)
  brpm_rest_client = BrpmRestClient.new

  source_request_ids = brpm_rest_client.get_requests_by_plan_id_and_stage_name_and_app_name(params["request_plan_id"], params["source_stage"], params["application"])

  raise "No requests found for application '#{params["application"]}' in stage '#{params["source_stage"]}' of this plan" if source_request_ids.count == 0

  source_requests = source_request_ids.map { |source_request_id| brpm_rest_client.get_request_by_id(source_request_id) }
                                      .sort_by { |request| request["created_at"] }

  source_requests
end

def step_has_incremental_deployment(correction_source_step, source_steps_with_same_name)
  brpm_rest_client = BrpmRestClient.new

  incremental_deployment = false
  if source_steps_with_same_name.count > 1
    BrpmAuto.log "Already multiple steps with the same name, this means that it is a step that has a component with incremental deploy."
    incremental_deployment = true
  else
    if !source_steps_with_same_name.first["component"].nil? and !correction_source_step["component"].nil?
      if source_steps_with_same_name.first["component"]["id"] == correction_source_step["component"]["id"]
        if !source_steps_with_same_name.first["version_tag"].nil? and !correction_source_step["version_tag"].nil?
          BrpmAuto.log "Verifying if the associated component '#{correction_source_step["component"]["name"]}' uses incremental deployment ..."
          component = brpm_rest_client.get_component_by_id(correction_source_step["component"]["id"])
          incremental_deployment = (component.has_key?("properties") and component["properties"].any? { |property| property["name"] == "incremental_deployment" })

          if incremental_deployment and source_steps_with_same_name.first["version_tag"]["name"] == correction_source_step["version_tag"]["name"]
            raise "This component has incremental deployment and there already exists a step with the same component and version number."
          end
        end
      end
    end
  end

  incremental_deployment
end

def merge_source_request_steps(source_requests)
  brpm_rest_client = BrpmRestClient.new

  BrpmAuto.log "Getting the step details of the initial request ..."
  source_steps = source_requests.first["steps"].map { |source_step_summary| brpm_rest_client.get_step_by_id(source_step_summary["id"]) }
                                              .sort_by { |step| step["number"].to_f }

  #TODO: use work tasks to find the first post-deploy step
  post_deploy_step = source_steps.find { |step| step["name"] == "Post-deploy" }

  BrpmAuto.log "Merging the correction requests with the original request ..."
  source_requests[1..source_requests.count].each do |source_request|
    BrpmAuto.log "Merging the steps from correction request #{source_request["id"]} - #{source_request["name"] || "<no name>"} (#{source_request["steps"].count} steps)"
    source_request["steps"].sort_by { |step| step["number"].to_f }.each do |correction_source_step_summary|
      correction_source_step = brpm_rest_client.get_step_by_id(correction_source_step_summary["id"])
      BrpmAuto.log "Merging step '#{correction_source_step["name"]}' ..."

      source_steps_with_same_name = source_steps.find_all { |source_step| source_step["name"] == correction_source_step["name"] }

      if source_steps_with_same_name.count == 0
        BrpmAuto.log "No steps yet with the same name, so adding this step to the list ..."
        index = source_steps.index(post_deploy_step)
        source_steps.insert(index, correction_source_step)
        next
      end

      BrpmAuto.log "Verifying if the step has a component with incremental deployment ..."
      incremental_deployment = step_has_incremental_deployment(correction_source_step, source_steps_with_same_name)

      if incremental_deployment
        BrpmAuto.log "This step has a component with incremental deployment so adding it to the list ..."
        index = source_steps.index(source_steps_with_same_name.last)
        source_steps.insert(index + 1, correction_source_step)
      else
        BrpmAuto.log "Replacing the original step with this one in the list ..."
        index = source_steps.index(source_steps_with_same_name.first)
        source_steps[index] = correction_source_step
      end
    end
  end

  source_steps
end

def create_target_request(initial_source_request, source_steps, params)
  brpm_rest_client = BrpmRestClient.new

  target_request = {}
  target_request["name"] = params["request_name"].sub("Release", "Deploy")
  target_request["description"] = initial_source_request["description"]
  target_request["estimate"] = initial_source_request["estimate"]
  target_request["owner_id"] = initial_source_request["owner"]["id"]
  target_request["requestor_id"] = initial_source_request["requestor"]["id"]
  target_request["deployment_coordinator_id"] = initial_source_request["deployment_coordinator"]["id"]
  target_request["app_ids"] = initial_source_request["apps"][0]["id"]

  plan_stage_id = brpm_rest_client.get_plan_stage_id(params["request_plan_id"], params["target_stage"])
  target_request["plan_member_attributes"] = { "plan_id" => params["request_plan_id"], "plan_stage_id" => plan_stage_id }
  target_request["environment"] = params["target_env"]
  target_request["execute_now"] = (params["execute_target_request"] == 'Yes') #TODO: doesn't work - maybe try starting it explicitly after creation

  BrpmAuto.log "Creating the target request ..."
  target_request = brpm_rest_client.create_request_from_hash(target_request)

  BrpmAuto.log "Creating the target steps ..."
  procedure_mapping = {}
  source_steps.each do |source_step|
    BrpmAuto.log "Creating target step for step #{source_step["name"]} ..."

    target_step = {}
    if source_step["procedure"]
      #TODO doesnt work yet
      target_step["parent_id"] = procedure_mapping[source_step["parent_id"]]
    end
    target_step["request_id"] = target_request["id"]
    target_step["name"] = source_step["name"]
    target_step["description"] = source_step["description"]
    target_step["owner_type"] = source_step["owner_type"]
    target_step["owner_id"] = source_step["owner"]["id"] unless source_step["owner"].nil?
    target_step["manual"] = source_step["manual"]
    target_step["script_id"] = source_step["script"]["id"] unless source_step["script"].nil?
    target_step["script_type"] = source_step["script_type"]
    target_step["procedure"] = source_step["procedure"]

    unless source_step["installed_component"].nil?
      installed_components = brpm_rest_client.get_installed_components_by({ "app_name" => source_step["installed_component"]["app"]["name"],
                                                           "component_name" => source_step["installed_component"]["component"]["name"],
                                                           "environment_name" => params["target_env"] })

      raise "No installed component found for app '#{source_step["installed_component"]["app"]["name"]}', component '#{source_step["installed_component"]["component"]["name"]}' and environment '#{source_step["installed_component"]["environment"]["name"]}'" if installed_components.count == 0

      target_step["installed_component_id"] = installed_components[0]["id"]

      unless source_step["version_tag"].nil?
        version_tags = brpm_rest_client.get_version_tags_by({ "name" => source_step["version_tag"]["name"],
                                             "app_name" => source_step["installed_component"]["app"]["name"],
                                             "component_name" => source_step["installed_component"]["component"]["name"],
                                             "environment_name" => params["target_env"] })

        raise "No version tag found for app '#{source_step["installed_component"]["app"]["name"]}', component '#{source_step["installed_component"]["component"]["name"]}', environment '#{params["target_env"]}' and version '#{source_step["version_tag"]["name"]}'" if version_tags.count == 0

        target_step["version_tag_id"] = version_tags[0]["id"]
      end
    end

    target_step["component_id"] = source_step["component"]["id"] unless source_step["component"].nil?

    target_step["own_version"] = source_step["own_version"]
    target_step["component_version"] = source_step["component_version"]
    target_step["custom_ticket_id"] = source_step["custom_ticket_id"]
    target_step["release_content_item_id"] = source_step["release_content_item_id"]
    target_step["on_plan"] = source_step["on_plan"]
    target_step["should_execute"] = source_step["should_execute"]
    target_step["execute_anytime"] = source_step["execute_anytime"]
    target_step["start_by"] = source_step["start_by"]
    target_step["location_detail"] = source_step["location_detail"]
    target_step["estimate"] = source_step["estimate"]
    target_step["different_level_from_previous"] = source_step["different_level_from_previous"]
    target_step["phase_id"] = source_step["phase"]["id"] unless source_step["phase"].nil?
    target_step["runtime_phase_id"] = source_step["runtime_phase"]["id"] unless source_step["runtime_phase"].nil?

    target_step = brpm_rest_client.create_step_from_hash(target_step)

    BrpmAuto.log "Created target step for step #{source_step["name"]} (#{target_step["position"]})."

    procedure_mapping[source_step["id"]] = target_step["id"] if source_step["procedure"]
  end

  target_request
end

brpm_rest_client = BrpmRestClient.new
params = BrpmAuto.params

BrpmAuto.log "Getting the source requests ..."
source_requests = brpm_rest_client.get_source_requests(params)

if params["request_template"].nil? || params["request_template"].empty?
  initial_source_request = source_requests.first
  BrpmAuto.log "Found initial source request #{initial_source_request["id"]} - #{initial_source_request["name"] || "<no name>"}"

  BrpmAuto.log "Merging the source request steps ..."
  source_steps = merge_source_request_steps(source_requests)

  BrpmAuto.log "Creating the target request ..."
  target_request = create_target_request(initial_source_request, source_steps, params)
else
  target_request = brpm_rest_client.create_request_for_plan_from_template(params["request_plan_id"], params["target_stage"], params["request_template"], params["request_name"].sub("Release", "Deploy"), params["target_env"], (params["execute_target_request"] == 'Yes'))
end

BrpmAuto.log "Moving the source requests to the stage '#{params["source_stage"]} - Archived' ..."
source_requests.each do |source_request|
  brpm_rest_client.move_request_to_plan_and_stage(source_request["id"], params["request_plan_id"], "#{params["source_stage"]} - Archived")
end

BrpmAuto.log "Adding the promoted request' id to the request_params ..."
BrpmAuto.request_params["promoted_request_id"] = target_request["id"]

