class BrpmRestClient
  def initialize(brpm_url = BrpmAuto.params.brpm_url, brpm_api_token= BrpmAuto.params.brpm_api_token)
    @brpm_url = brpm_url
    @brpm_api_token = brpm_api_token
  end

  # Performs a get on the passed model
  #
  # ==== Attributes
  #
  # * +model_name+ - rpm model [requests, plans, steps, version_tags, etc]
  # * +model_id+ - id of a specific item in the model (optional)
  # * +options+ - hash of options includes
  #    +filters+ - string of the filter text: filters[BrpmAuto.login]=bbyrd
  #    includes all the Rest.rest_call options
  #
  # ==== Returns
  #
  # * hash of http response
  def get(model_name, model_id = nil, options = {})
    url = get_brpm_url(model_name, model_id) if get_option(options, "filters") == ""
    url = get_brpm_url(model_name, nil, options["filters"]) if get_option(options, "filters") != ""
    result = Rest.get(url, options)

    result = brpm_get "v1/#{model_name}#{model_id == nil ? "" : "/#{model_id}" }"
  end

  # Performs a put on the passed model
  #  use this to update a single record
  # ==== Attributes
  #
  # * +model_name+ - rpm model [requests, plans, steps, version_tags, etc]
  # * +model_id+ - id of a specific item in the model (optional)
  # * +data+ - hash of the put data
  # * +options+ - hash of options includes
  #    includes all the Rest.rest_call options
  #
  # ==== Returns
  #
  # * hash of http response
  def update(model_name, model_id, data, options = {})
    url = get_brpm_url(model_name, model_id)
    options["data"] = data
    result = Rest.put(url, options)
    result
  end

  # Performs a post on the passed model
  #  use this to create a new record
  # ==== Attributes
  #
  # * +model_name+ - rpm model [requests, plans, steps, version_tags, etc]
  # * +data+ - hash of the put data
  # * +options+ - hash of options includes
  #    includes all the Rest.rest_call options
  #
  # ==== Returns
  #
  # * hash of http response
  def create(model_name, data, options = {})
    options["data"] = data
    url = get_brpm_url(model_name)
    result = Rest.post(url, options)
    result
  end

  def get_user_by_id(user_id)
    result = brpm_get "v1/users/#{user_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for user #{user_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_user_by_name(first_name, last_name)
    result = brpm_get "v1/users?filters[first_name]=#{first_name}&filters[last_name]=#{last_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Could not find user #{first_name} #{last_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_group_by_name(name)
    result = brpm_get "v1/groups?filters[name]=#{name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Could not find group #{name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_property_by_name(property_name)
    result = brpm_get "v1/properties?filters[name]=#{property_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Could not find property #{property_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_server(server_name, dns = nil, environment_ids = nil, ip_address = nil, os_platform = nil, property_ids = nil)
    server={}
    server["name"] = server_name
    server["environment_ids"] = environment_ids unless environment_ids.nil?
    server["ip_address"] = ip_address unless ip_address.nil?
    server["os_platform"] = os_platform unless os_platform.nil?
    server["property_ids"] = property_ids unless property_ids.nil?

    result = brpm_post "v1/servers", { :server => server }

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if Rest.already_exists_error(result)
        BrpmAuto.log "This server already exists."
        result_hash = get_server_by_name(server_name)
        existing_environment_ids = result_hash["environments"].map { |env| env["id"] }

        environment_ids ||= []

        (environment_ids - existing_environment_ids).each do |environment_id|
          link_environment_to_server(environment_id, server_name)
        end
      else
        raise "Could not create server: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_server_by_name(server_name)
    result = brpm_get "v1/servers?filters[name]=#{server_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Could not find server #{server_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_request_templates_by_app(app_name)
    app = get_app_by_name(app_name)

    result = brpm_get "v1/request_templates?filters[app_id]=#{app["id"]}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash={}
      else
        raise "Could not find request templates for app #{app_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_apps
    result = brpm_get "v1/apps"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error getting apps: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_app_by_id(app_id)
    result = brpm_get "v1/apps/#{app_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for application #{app_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_app_by_name(app_name)
    result = brpm_get "v1/apps?filters[name]=#{app_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Could not find application #{app_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_component_by_id(component_id)
    result = brpm_get "v1/components/#{component_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for component #{component_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_environments_of_application(app_name)
    app = get_app_by_name(app_name)
    app["environments"]
  end

  def get_environment_by_id(environment_id)
    result = brpm_get "v1/environments/#{environment_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for environment #{environment_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_environment_by_name(environment_name)
    result = brpm_get "v1/environments?filters[name]=#{environment_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Error searching for environment #{environment_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_environment(environment_name)
    environment={}
    environment["name"]=environment_name

    result = brpm_post "v1/environments", { :environment => environment }

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if Rest.already_exists_error(result)
        BrpmAuto.log "This environment already exists. Continuing ..."
        result_hash = get_environment_by_name(environment_name)
      else
        raise "Could not create environment: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def rename_environment(environment_id, environment_name)
    environment={}
    environment["name"]="#{Time.now.strftime("%Y%m%d%H%M%S")} #{environment_name}"

    result = brpm_put "v1/environments/#{environment_id}", { :environment => environment }

    unless result["status"] == "success"
      raise "Could not rename environment: #{result["error_message"]}"
    end
  end

  def delete_environment(environment_name)
    environment = get_environment_by_name(environment_name)

    if environment.nil?
      BrpmAuto.log "This environment doesn't exist. Continuing ..."
      return
    end

    rename_environment(environment["id"], environment_name)

    result = brpm_delete "v1/environments/#{environment["id"]}"

    unless result["status"] == "success"
      raise "Could not delete environment: #{result["error_message"]}"
    end
  end

  def link_environment_to_server(environment_id, server_name)
    server = get_server_by_name(server_name)

    server_to_update={}
    server_to_update["environment_ids"] = server["environments"].map{|f| f["id"]}

    if server_to_update["environment_ids"].include?(environment_id)
      BrpmAuto.log "This server is already linked to the application. Continuing..."
      return
    end

    server_to_update["environment_ids"].push(environment_id)

    result = brpm_put "v1/servers/#{server["id"]}", { :server => server_to_update }

    unless result["status"] == "success"
      raise "Could not link environment to server: #{result["error_message"]}"
    end
  end

  def unlink_environment_from_server(environment_name, server_name)
    server = get_server_by_name(server_name)

    if server.nil?
      BrpmAuto.log "This server doesn't exist. Continuing ..."
      return
    end

    environment = get_environment_by_name(environment_name)

    if environment.nil?
      BrpmAuto.log "This environment doesn't exist. Continuing ..."
      return
    end

    server_to_update={}
    server_to_update["environment_ids"] = server["environments"].map{|f| f["id"]}

    unless server_to_update["environment_ids"].include?(environment["id"])
      BrpmAuto.log "This environment is not linked to the server. Continuing ..."
      return
    end

    server_to_update["environment_ids"].delete(environment["id"])

    result = brpm_put "v1/servers/#{server["id"]}", { :server => server_to_update}

    unless result["status"] == "success"
      raise "Could not unlink environment from server: #{result["error_message"]}"
    end
  end

  def link_environment_to_app(environment_id, app_name)
    app = get_app_by_name(app_name)

    app_to_update={}
    app_to_update["environment_ids"] = app["environments"].map{|f| f["id"]}

    if app_to_update["environment_ids"].include?(environment_id)
      BrpmAuto.log "This environment is already linked to the application. Continuing..."
      return
    end

    app_to_update["environment_ids"].push(environment_id)

    result = brpm_put "v1/apps/#{app["id"]}", { :app => app_to_update}

    unless result["status"] == "success"
      raise "Could not link environment to app: #{result["error_message"]}"
    end
  end

  def unlink_environment_from_app(environment_name, app_name)
    app = get_app_by_name(app_name)

    if app.nil?
      BrpmAuto.log "This application doesn't exist. Continuing ..."
      return
    end

    environment = get_environment_by_name(environment_name)

    if environment.nil?
      BrpmAuto.log "This environment doesn't exist. Continuing ..."
      return
    end

    app_to_update={}
    app_to_update["environment_ids"] = app["environments"].map{|f| f["id"]}

    unless app_to_update["environment_ids"].include?(environment["id"])
      BrpmAuto.log "This environment is not linked to the app. Continuing ..."
      return
    end

    app_to_update["environment_ids"].delete(environment["id"])

    result = brpm_put "v1/apps/#{app["id"]}", { :app => app_to_update}

    unless result["status"] == "success"
      raise "Could not unlink environment from app: #{result["error_message"]}"
    end
  end

  def get_installed_component_by_id(component_id)
    result = brpm_get "v1/installed_components/#{component_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for installed component #{component_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_installed_component(component_name, environment_name)
    result = brpm_get "v1/installed_components?filters[component_name]=#{component_name}&filters[environment_name]=#{environment_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Error searching for installed component #{component_name} / #{environment_name}  #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_installed_components_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/installed_components#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for installed_components by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_installed_component(component_name, component_version, environment_name, app_name, server_name)
    installed_comp = {}
    installed_comp["app_name"] = app_name
    installed_comp["component_name"] = component_name
    installed_comp["environment_name"] = environment_name
    installed_comp["version"]= component_version
    installed_comp["server_names"] = [ server_name ]

    result = brpm_post "v1/installed_components", { :installed_component => installed_comp }

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if Rest.already_exists_error(result)
        BrpmAuto.log "This installed component already exists."
        result_hash = get_installed_component(component_name, environment_name)
        result_hash = get_installed_component_by_id(result_hash["id"])

        servers = result_hash["servers"].map { |server| server["name"] }

        BrpmAuto.log "Verifying if the existing installed component is already linked to the server ..."
        if servers.include?(server_name)
          BrpmAuto.log "The existing installed component is already linked to the server. Continuing ..."
        else
          BrpmAuto.log "The existing installed component is not yet linked to the server, doing it now ..."
          servers.push server_name
          set_servers_of_installed_component(result_hash["id"], servers)
        end
      else
        raise "Could not create installed component: #{result["error_message"]}"
      end
    end

    BrpmAuto.log "Copying the version tags from environment [default] to environment #{environment_name} ..."
    copy_version_tags_of_app_and_comp_from_env_to_env(app_name, component_name, "[default]", environment_name)

    result_hash
  end

  def set_property_of_installed_component(installed_component_id, property, value)
    installed_comp= {}
    installed_comp["properties_with_values"] = {}
    installed_comp["properties_with_values"][property] = value

    result = brpm_put "v1/installed_components/#{installed_component_id}", { :installed_component => installed_comp }

    unless result["status"] == "success"
      raise "Could not set properties on installed component: #{result["error_message"]}"
    end
  end

  def get_server_group_from_step_id(step_id)
    step = get_step_by_id(step_id)

    installed_component = get_installed_component_by_id(step["installed_component"]["id"])

    return nil unless installed_component["server_group"]

    installed_component["server_group"]["name"]
  end

  def set_servers_of_installed_component(installed_component_id, server_names)
    installed_comp= {}
    installed_comp["server_names"] = server_names

    result = brpm_put "v1/installed_components/#{installed_component_id}", { :installed_component => installed_comp }

    unless result["status"] == "success"
      raise "Could not set servers on installed component: #{result["error_message"]}"
    end
  end

  def set_property_of_server(server_id, property_id, value)
    property = {}
    property["property_values_with_holders"] = {}
    property["property_values_with_holders"]["value_holder_type"] = "Server"
    property["property_values_with_holders"]["value_holder_id"] = server_id
    property["property_values_with_holders"]["value"] = value

    result = brpm_put "v1/properties/#{property_id}", { :property => property }

    unless result["status"] == "success"
      raise "Could not set property on server: #{result["error_message"]}"
    end
  end

  def create_version_tag(app_name, component_name, environment, version_tag_name)
    version_tag={}
    version_tag["name"] = version_tag_name
    version_tag["find_application"] = app_name
    version_tag["find_component"] = component_name
    version_tag["find_environment"] = environment
    version_tag["active"] = true

    result = brpm_post "v1/version_tags", { :version_tag => version_tag }

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if Rest.already_exists_error(result)
        BrpmAuto.log "This version tag already exists. Continuing ..."
        result_hash = get_version_tag(app_name, component_name, environment, version_tag_name)
      else
        raise "Could not create version tag: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def delete_version_tag(version_tag_id)
    result = brpm_delete "v1/version_tags/#{version_tag_id}"

    unless result["status"] == "success"
      raise "Could not delete version tag: #{result["error_message"]}"
    end
  end

  def get_version_tag(app_name, component_name, environment_name, version_tag_name)
    result = brpm_get "v1/version_tags?filters[app_name]=#{app_name}&filters[component_name]=#{component_name}&filters[environment_name]=#{environment_name}&filters[name]=#{version_tag_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Could not find application #{app_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_version_tags_by_app_and_comp_and_env(app_name, component_name, environment_name)
    result = brpm_get "v1/version_tags?filters[app_name]=#{app_name}&filters[component_name]=#{component_name}&filters[environment_name]=#{environment_name}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Could not find version tags for app #{app_name}, component #{component_name}, environment #{environment_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_version_tags_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/version_tags#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for version_tags by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def copy_version_tags_of_app_and_comp_from_env_to_env(app_name, component_name, source_env, target_env)
    source_version_tags = get_version_tags_by_app_and_comp_and_env(app_name, component_name, source_env)

    source_version_tags.each do |source_version_tag|
      create_version_tag(app_name, component_name, target_env, source_version_tag["name"])
    end
  end

  def get_plan_template_by_name(plan_template_name)
    result = brpm_get "v1/plan_templates?filters[name]=#{plan_template_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Error searching for plan template #{plan_template_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_plan(template_name, plan_name, date = nil)
    plan = {}
    plan["plan_template_name"] = template_name
    plan["name"] = plan_name
    plan["release_date"] = date.utc if date

    result = brpm_post "v1/plans", { :plan => plan }

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if Rest.already_exists_error(result)
        BrpmAuto.log "This plan already exists. Continuing ..."
        result_hash = get_plan_by_name(plan_name)
      else
        raise "Could not create plan: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def delete_plan(plan_id)
    result = brpm_delete "v1/plans/#{plan_id}"

    unless result["status"] == "success"
      raise "Could not delete plan: #{result["error_message"]}"
    end
  end

  def plan_plan(plan_id)
    plan = {}
    plan["aasm_event"] = "plan_it"

    result = brpm_put "v1/plans/#{plan_id}", { :plan => plan}

    unless result["status"] == "success"
      raise "Could not plan plan: #{result["error_message"]}"
    end
  end

  def start_plan(plan_id)
    plan = {}
    plan["aasm_event"] = "start"

    result = brpm_put "v1/plans/#{plan_id}", { :plan => plan}

    unless result["status"] == "success"
      raise "Could not start plan: #{result["error_message"]}"
    end
  end

  def cancel_plan(plan_id)
    plan = {}
    plan["aasm_event"] = "cancel"

    result = brpm_put "v1/plans/#{plan_id}", { :plan => plan}

    unless result["status"] == "success"
      raise "Could not cancel plan: #{result["error_message"]}"
    end
  end

  def get_plan_by_id(plan_id)
    result = brpm_get "v1/plans/#{plan_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for plan #{plan_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_plan_by_name(plan_name)
    result = brpm_get "v1/plans?filters[name]=#{plan_name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Error searching for plan #{plan_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_plans_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/plans#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for plans by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_plan_stage_id(plan_id, stage_name)
    plan = get_plan_by_id(plan_id)

    plan["plan_template"]["stages"].each do |stage|
      return stage["id"].to_i if stage["name"] == stage_name
    end

    raise "Could not find a stage named #{stage_name} for plan #{plan_id}"
  end

  def get_plan_stage_by_id(plan_stage_id)
    result = brpm_get "v1/plan_stages/#{plan_stage_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for plan stage #{plan_stage_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_route_by_id(route_id)
    result = brpm_get "v1/routes/#{route_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for route #{route_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_constraints
    result = brpm_get "v1/constraints"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for constraints: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_plan_route_by_plan_and_app(plan_id, app_id)
    result = brpm_get "v1/plan_routes?filters[plan_id]=#{plan_id}&filters[app_id]=#{app_id}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Error searching for plan route for plan id #{plan_id} and app id #{app_id}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_route_gate_by_id(route_gate_id)
    result = brpm_get "v1/route_gates/#{route_gate_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for route gate #{route_gate_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_first_environment_of_route_for_plan_and_app(plan_id, app_id)
    BrpmAuto.log "Getting the plan route..."
    plan_route = get_plan_route_by_plan_and_app(plan_id, app_id)

    unless plan_route
      BrpmAuto.log "No plan route found for plan id #{plan_id} and app id #{app_id}."
      return nil
    end

    BrpmAuto.log "Getting the route..."
    route = get_route_by_id(plan_route["route"]["id"])

    route_gate = route["route_gates"].find { |route_gate| route_gate["position"] == 1 }

    return route_gate["environment"]["name"]
  end

  def create_request(template_name, name, environment, execute_now, data = {})
    request = {}
    request["template_name"] = template_name
    request["name"] = name
    request["environment"] = environment
    request["execute_now"] = execute_now
    request["data"] = data

    result = brpm_post "v1/requests", { :request => request }

    unless result["status"] == "success"
      raise "Could not create the request: #{result["error_message"]}"
    end

    result["response"]
  end

  def create_request_from_hash(request)
    result = brpm_post "v1/requests", { :request => request }

    unless result["status"] == "success"
      raise "Could not create the request: #{result["error_message"]}"
    end

    result["response"]
  end

  def create_request_for_plan(plan_id, stage_name, name, requestor_id, app_name, env_name, execute_now, data = nil)
    plan_stage_id = get_plan_stage_id(plan_id, stage_name)

    request = {}
    request["plan_member_attributes"] = { "plan_id" => plan_id, "plan_stage_id" => plan_stage_id }
    request["name"] = name
    request["requestor_id"] = requestor_id
    request["deployment_coordinator_id"] = requestor_id
    request["app_ids"] = [ get_app_by_name(app_name)["id"] ]
    request["environment"] = env_name
    request["execute_now"] = execute_now
    request["data"] = data

    result = brpm_post "v1/requests", { :request => request }

    unless result["status"] == "success"
      raise "Could not create the request: #{result["error_message"]}"
    end

    result["response"]
  end

  def create_request_for_plan_from_template(plan_id, stage_name, template_name, name, env_name, execute_now, data = {})
    plan_stage_id = get_plan_stage_id(plan_id, stage_name)

    request = {}
    request["plan_member_attributes"] = { "plan_id" => plan_id, "plan_stage_id" => plan_stage_id }
    request["template_name"] = template_name
    request["name"] = name
    request["environment"] = env_name
    request["execute_now"] = execute_now
    request["data"] = data

    result = brpm_post "v1/requests", { :request => request }

    unless result["status"] == "success"
      raise "Could not create the request: #{result["error_message"]}"
    end

    result["response"]
  end

  def delete_request(request_id)
    result = brpm_delete "v1/requests/#{request_id}"

    unless result["status"] == "success"
      raise "Could not delete request: #{result["error_message"]}"
    end
  end

  def move_request_to_plan_and_stage(request_id, plan_id, stage_name)
    plan_stage_id = get_plan_stage_id(plan_id, stage_name)

    request = {}
    request["plan_member_attributes"] = { "plan_id" => plan_id, "plan_stage_id" => plan_stage_id }

    result = brpm_put "v1/requests/#{request_id}", { :request => request }

    unless result["status"] == "success"
      raise "Could not create the request: #{result["error_message"]}"
    end

    result["response"]
  end

  def plan_request(request_id)
    request = {}
    request["aasm_event"] = "plan_it"

    result = brpm_put "v1/requests/#{request_id}", { :request => request}

    unless result["status"] == "success"
      raise "Could not plan request: #{result["error_message"]}"
    end
  end

  def start_request(request_id)
    request = {}
    request["aasm_event"] = "start"

    result = brpm_put "v1/requests/#{request_id}", { :request => request}

    unless result["status"] == "success"
      raise "Could not start request: #{result["error_message"]}"
    end
  end

  def get_request_by_id(request_id)
    result = brpm_get "v1/requests/#{request_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for request #{request_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_requests_by_name(request_name)
    result = brpm_get "v1/requests?filters[name]=#{request_name}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash=nil
      else
        raise "Error searching for request #{request_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_requests_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/requests#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for request by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_requests_by_name_and_plan_and_stage(request_name, plan_name, stage_name)
    result = brpm_get "v1/requests?filters[name]=#{request_name}"

    if result["status"] == "success"
      result_hash = result["response"].select { |request| request["plan_member"]["plan"]["name"] == plan_name and request["plan_member"]["stage"]["name"] == stage_name }
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for request #{request_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_requests_by_plan_id_and_stage_name(plan_id, stage_name)
    result = brpm_get "v1/plans/#{plan_id}"

    if result["status"] == "success"
      members_in_plan = result["response"]["members"]
      members_in_stage = members_in_plan.select { |member| member["stage"]["name"] == stage_name and member.has_key?("request") }
      result_hash = members_in_stage.map { |member| { "id" => member["request"]["number"].to_i - 1000, "number" => member["request"]["number"], "name" => member["request"]["name"] } }
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for requests by plan id #{plan_id} and stage name #{stage_name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_requests_by_plan_id_and_stage_name_and_app_name(plan_id, stage_name, app_name)
    requests_by_plan_and_stage = get_requests_by_plan_id_and_stage_name(plan_id, stage_name)
    request_ids_1 = requests_by_plan_and_stage.map { |request| request["id"] }

    requests_by_app = get_requests_by({ "app_id" => get_app_by_name(app_name)["id"] })
    request_ids_2 = requests_by_app.map { |request| request["id"] }

    request_ids_1 & request_ids_2
  end

  def update_request_from_hash(request)
    result = brpm_put "v1/requests/#{request["id"]}", { :request => request }

    unless result["status"] == "success"
      raise "Could not update the request: #{result["error_message"]}"
    end

    result["response"]
  end

  def monitor_request(request_id, options = {})
    target_status = "complete"

    max_time = 15*60 # seconds
    max_time = 60 * options[:max_time].to_i if options.has_key?(:max_time) and !options[:max_time].nil?

    monitor_step_name = (options.has_key?(:monitor_step_name) and !options[:monitor_step_name].nil?) ? options[:monitor_step_name] : "none"
    monitor_step_id = (options.has_key?(:monitor_step_id) and !options[:monitor_step_id].nil?) ? options[:monitor_step_id] : "none"

    checking_interval = 15 #seconds
    checking_interval = options[:checking_interval].to_i if options.has_key?(:checking_interval) and !options[:checking_interval].nil?

    req_status = "none"
    start_time = Time.now
    elapsed = 0
    BrpmAuto.log "Starting the monitoring loop for request #{request_id} with an interval of #{checking_interval} seconds and a maximum time of #{max_time} seconds ..."
    until (elapsed > max_time || req_status == target_status)
      request = get_request_by_id(request_id)

      if monitor_step_name == "none" and monitor_step_id == "none"
        req_status = request["aasm_state"]
      else
        found = false
        request["steps"].each do |step|
          if (monitor_step_name != "none" and step["name"] == monitor_step_name) or
              (monitor_step_id != "none" and step["id"] == monitor_step_id)
            req_status = step["aasm_state"]
            found = true
            break
          end
        end
        unless found
          raise "Step #{monitor_step_name} not found in request #{request_id}"
        end
      end

      if req_status == target_status
        BrpmAuto.log "Found request in #{target_status} status! Returning."
        break
      end

      if req_status == "problem"
        raise "Found request #{request_id} in problem state."
      end

      BrpmAuto.log "\tWaiting(#{elapsed.floor.to_s}) - Current status: #{req_status}"
      sleep(checking_interval)
      elapsed = Time.now - start_time
    end

    if elapsed > max_time
      raise "Maximum time: #{max_time}(secs) reached.  Status is: #{req_status}, looking for: #{target_status}"
    end
  end

  def create_step_from_hash(step)
    result = brpm_post "v1/steps", { :step => step }

    unless result["status"] == "success"
      raise "Could not create the step: #{result["error_message"]}"
    end

    result["response"]
  end

  def create_step(request_id, name, owner_type, owner_id)
    step = {}
    step["request_id"] = request_id
    step["name"] = name
    step["owner_type"] = owner_type
    step["owner_id"] = owner_id

    result = brpm_post "v1/steps", { :step => step }

    unless result["status"] == "success"
      raise "Could not create the step: #{result["error_message"]}"
    end

    result["response"]
  end

  def get_step_by_id(step_id)
    result = brpm_get "v1/steps/#{step_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for step #{step_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def update_step_from_hash(step)
    result = brpm_put "v1/steps/#{step["id"]}", { :step => step }

    unless result["status"] == "success"
      raise "Could not update the step: #{result["error_message"]}"
    end

    result["response"]
  end

  def get_steps_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/steps#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for steps by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_run_by_id(run_id)
    result = brpm_get "v1/runs/#{run_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for run #{run_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def set_version_tag_of_steps_for_component(request, component_name, version_tag_name)
    steps_for_component = request["steps"].select{ |step| step["component_name"] == component_name}

    return if steps_for_component.count == 0

    version_tag = get_version_tag(request["apps"].first["name"], component_name, request["environment"]["name"], version_tag_name)

    if version_tag.nil?
      raise "No version tag found for app #{request["apps"].first["name"]}, component #{component_name}, environment #{request["environment"]["name"]}, version tag name #{version_tag_name}"
    end

    steps_for_component.each do |step|
      step_data = {}
      step_data["version_tag_id"] = version_tag["id"]
      step_data["component_version"] = version_tag_name

      result = brpm_put "v1/steps/#{step["id"]}", { :step => step_data}

      unless result["status"] == "success"
        raise "Could not set the version tag of the step: #{result["error_message"]}"
      end
    end
  end

  def set_version_of_steps_for_component(request, component_name, version)
    steps_for_component = request["steps"].select{ |step| step["component_name"] == component_name}
    steps_for_component.each do |step|
      step_data = {}
      step_data["component_version"] = version

      result = brpm_put "v1/steps/#{step["id"]}", { :step => step_data}

      unless result["status"] == "success"
        raise "Could not set the version of the step: #{result["error_message"]}"
      end
    end
  end

  def get_ticket_by_foreign_id(ticket_foreign_id)
    result = brpm_get "v1/tickets?filters[foreign_id]=#{ticket_foreign_id}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash = nil
      else
        raise "Could not find ticket #{ticket_foreign_id}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_tickets_by_request_id(request_id)
    result = brpm_get "v1/tickets?filters[request_id]=#{request_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for tickets by rquest id #{request_id}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_tickets_by_run_id_and_request_state(run_id, state)
    BrpmAuto.log "Getting the requests that are part of run #{run_id} and have state #{state}..."
    run = get_run_by_id(run_id)
    request_ids = run["plan_members"].select { |member| member.has_key?("request") and member["request"]["aasm_state"] == state }.map { |member| member["request"]["id"] }
    BrpmAuto.log "Found #{request_ids.count} requests."

    BrpmAuto.log "Getting the tickets that are linked to each of the found requests..."
    tickets = []
    request_ids.each do |request_id|
      tickets_for_request = get_tickets_by_request_id(request_id)
      tickets = tickets.merge(tickets_for_request)
    end
    BrpmAuto.log "Found #{tickets.count} tickets in total."

    tickets
  end

  def get_tickets_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/tickets#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for tickets by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_ticket_from_hash(ticket)
    result = brpm_post "v1/tickets", { :ticket => ticket }

    unless result["status"] == "success"
      raise "Could not create the ticket: #{result["error_message"]}"
    end

    result["response"]
  end

  def update_ticket_from_hash(ticket)
    result = brpm_put "v1/tickets/#{ticket["id"]}", { :ticket => ticket }

    unless result["status"] == "success"
      raise "Could not update the ticket: #{result["error_message"]}"
    end

    result["response"]
  end

  def create_or_update_ticket(ticket)
    BrpmAuto.log "Checking if the corresponding ticket already exists ..."
    existing_ticket = get_ticket_by_foreign_id ticket["foreign_id"]

    if existing_ticket.nil?
      BrpmAuto.log "Ticket doesn't exist yet."
      ticket_already_exists=false
    else
      BrpmAuto.log "Ticket already exists."
      ticket_already_exists=true

      ticket["id"] = existing_ticket["id"].to_s
      ticket["extended_attributes_attributes"] = sync_attributes(existing_ticket["extended_attributes"], ticket["extended_attributes_attributes"])
    end

    now = Time.now.to_s
    sync_attribute "first received", now, ticket["extended_attributes_attributes"] unless ticket_already_exists
    sync_attribute "last updated", now, ticket["extended_attributes_attributes"]

    data = {}
    data["ticket"] = ticket

    if ticket_already_exists
      BrpmAuto.log "Updating the ticket ..."
      update_ticket_from_hash(ticket)
      BrpmAuto.log "Ticket is updated."
    else
      BrpmAuto.log "Creating the ticket ..."
      create_ticket_from_hash(ticket)
      BrpmAuto.log "Ticket is created."
    end
  end

  def get_project_servers
    result = brpm_get "v1/project_servers"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error getting project servers: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_id_for_project_server_type(integration_server_type)
    case integration_server_type.downcase
    when "Jira".downcase
      return 2
    when "Hudson/Jenkins".downcase, "Jenkins".downcase
      return 5
    when "Remedy via AO".downcase, "AO".downcase, "AtriumOrchestrator".downcase
      return 8
    when "BMC Application Automation".downcase, "Bladelogic".downcase
      return 9
    when "RLM Deployment Engine".downcase, "BRPD".downcase
      return 10
    else
      return nil
    end
  end

  def get_list_by_id(list_id)
    result = brpm_get "v1/lists/#{list_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for list #{list_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_list_by_name(name)
    result = brpm_get "v1/lists?filters[name]=#{name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash = nil
      else
        raise "Could not find list item #{name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_list_from_hash(list)
    result = brpm_post "v1/lists", { :list => list }

    unless result["status"] == "success"
      raise "Could not create the list: #{result["error_message"]}"
    end

    result["response"]
  end

  def update_list_from_hash(list)
    result = brpm_put "v1/lists/#{list["id"]}", { :list => list }

    unless result["status"] == "success"
      raise "Could not update the list: #{result["error_message"]}"
    end

    result["response"]
  end

  def archive_list(list_id)
    result = brpm_put "v1/lists/#{list_id}", { :toggle_archive => true }

    unless result["status"] == "success"
      raise "Could not archive the list: #{result["error_message"]}"
    end

    result["response"]
  end

  def delete_list(list_id)
    result = brpm_delete "v1/lists/#{list_id}"

    unless result["status"] == "success"
      raise "Could not delete the list: #{result["error_message"]}"
    end

    result["response"]
  end

  def get_list_item_by_id(list_item_id)
    result = brpm_get "v1/list_items/#{list_item_id}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      raise "Error searching for list item #{list_item_id}: #{result["error_message"]}"
    end

    result_hash
  end

  def get_list_item_by_name(list_name, list_item_name)
    result = brpm_get "v1/list_items?filters[list_name]=#{list_name}&filters[value_text]=#{list_item_name}"

    if result["status"] == "success"
      result_hash = get_list_item_by_id(result["response"].first["id"])
    else
      if result["code"] == 404
        result_hash = nil
      else
        raise "Could not find list item #{name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_list_items_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/list_items#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for list items by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_list_item_from_hash(list_item)
    result = brpm_post "v1/list_items", { :list_item => list_item }

    unless result["status"] == "success"
      raise "Could not create the list item: #{result["error_message"]}"
    end

    result["response"]
  end

  def update_list_item_from_hash(list_item)
    result = brpm_put "v1/list_items/#{list_item["id"]}", { :list_item => list_item }

    unless result["status"] == "success"
      raise "Could not update the list item: #{result["error_message"]}"
    end

    result["response"]
  end

  def create_or_update_list_item(list_name, list_item_name)
    BrpmAuto.log "Checking if the corresponding list item already exists ..."
    existing_list_item = get_list_item_by_name(list_name, list_item_name)

    list_item = {}
    list_item["value_text"] = list_item_name
    if existing_list_item.nil?
      BrpmAuto.log "List item doesn't exist yet."
      list_item_already_exists=false

      list = get_list_by_name(list_name)
      if list
        list_item["list_id"] = list["id"]
      else
        raise "A list with the name #{list_name} doesn't exist."
      end

    else
      BrpmAuto.log "List item already exists."
      list_item_already_exists=true

      list_item["id"] = existing_list_item["id"].to_s
    end

    data = {}
    data["list_item"] = list_item

    if list_item_already_exists
      BrpmAuto.log "Updating the list item..."
      list_item = update_list_item_from_hash(list_item)
      BrpmAuto.log "list_item is updated."
    else
      BrpmAuto.log "Creating the list item..."
      list_item = create_list_item_from_hash(list_item)
      BrpmAuto.log "List item is created."
    end

    list_item
  end

  def archive_list_item(list_item_id)
    result = brpm_put "v1/list_items/#{list_item_id}", { :toggle_archive => true }

    unless result["status"] == "success"
      raise "Could not archive the list item: #{result["error_message"]}"
    end

    result["response"]
  end

  def delete_list_item(list_item_id)
    result = brpm_delete "v1/list_items/#{list_item_id}"

    unless result["status"] == "success"
      raise "Could not delete the list item: #{result["error_message"]}"
    end

    result["response"]
  end

  def get_script_by_name(name)
    result = brpm_get "v1/scripts?filters[name]=#{name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash = nil
      else
        raise "Could not find script #{name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def get_scripts_by(filter)
    filter_string = "?"
    filter.each do |key, value|
      filter_string += "filters[#{key}]=#{value}&"
    end
    filter_string = filter_string[0..-1]

    result = brpm_get "v1/scripts#{filter_string}"

    if result["status"] == "success"
      result_hash = result["response"]
    else
      if result["code"] == 404
        result_hash = {}
      else
        raise "Error searching for scripts by #{filter_string}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def create_script_from_hash(script)
    result = brpm_post "v1/scripts", { :script => script }

    unless result["status"] == "success"
      raise "Could not create the script: #{result["error_message"]}"
    end

    result["response"]
  end

  def update_script_from_hash(script)
    result = brpm_put "v1/scripts/#{script["id"]}", { :script => script }

    unless result["status"] == "success"
      raise "Could not update the script: #{result["error_message"]}"
    end

    result["response"]
  end

  def create_or_update_script(script)
    BrpmAuto.log "Checking if the corresponding script already exists ..."
    existing_script = get_script_by_name script["name"]

    if existing_script.nil?
      BrpmAuto.log "Script doesn't exist yet."
      script_already_exists=false
    else
      BrpmAuto.log "Script already exists."
      script_already_exists=true

      script["id"] = existing_script["id"].to_s
    end

    data = {}
    data["script"] = script

    if script_already_exists
      BrpmAuto.log "Updating the script..."
      script = update_script_from_hash(script)
      BrpmAuto.log "Script is updated."
    else
      BrpmAuto.log "Creating the script..."
      script = create_script_from_hash(script)
      BrpmAuto.log "Script is created."
    end

    script
  end

  def get_work_task_by_name(name)
    result = brpm_get "v1/work_tasks?filters[name]=#{name}"

    if result["status"] == "success"
      result_hash = result["response"].first
    else
      if result["code"] == 404
        result_hash = nil
      else
        raise "Could not find work_task #{name}: #{result["error_message"]}"
      end
    end

    result_hash
  end

  def sync_attributes(existing_attributes, updated_attributes)
    existing_attributes ||= []
    updated_attributes ||= []

    updated_attributes.each do |updated_attribute|
      existing_attribute = existing_attributes.find { |existing_attribute| existing_attribute["name"] == updated_attribute["name"] }
      if existing_attribute.nil?
        existing_attributes.push(updated_attribute)
      else
        existing_attribute["value_text"] = updated_attribute["value_text"]
      end
    end
    existing_attributes
  end

  def get_attribute_value name, attributes
    attribute = attributes.find { |attribute| attribute["name"] == name }

    return attribute["value_text"] unless attribute.nil?
  end

  def sync_attribute name, value, attributes
    attribute = attributes.find { |attribute| attribute["name"] == name }

    if attribute.nil?
      attribute = {}
      attribute["name"] = name
      attributes.push(attribute)
    end

    attribute["value_text"] = value
  end

  # Sends an email based on step recipients
  #
  # ==== Attributes
  #
  # * +subject+ - text of email subject
  # * +body+ - text of email body
  #
  # ==== Returns
  #
  # * empty string
  def notify(body, subject = "Mail from automation", recipients = nil, step_id = BrpmAuto.params.step_id)
    data = { "filters" => { "notify" => { "body" => body, "subject" => subject } } }
    data["filters"]["notify"]["recipients"] = recipients unless recipients.nil?

    result = brpm_get "v1/steps/#{step_id}/notify", { :data => data } # a REST GET with a request body???
  end

  private

  def add_token(path)
    path + (path.include?("?") ? "&" : "?") + "token=#{@brpm_api_token}"
  end

  def get_brpm_url(model_name, id = nil, filters = nil)
    url = "#{@brpm_url}/v1/#{model_name}#{id == nil ? "" : "/#{id}" }"
    url += "?#{filters}" if filters

    add_token(url)
  end

  def brpm_get(path, options = {})
    Rest.get("#{@brpm_url}/#{add_token(path)}", options)
  end

  def brpm_post(path, data, options = {})
    Rest.post("#{@brpm_url}/#{add_token(path)}", data, options)
  end

  def brpm_put(path, data, options = {})
    Rest.put("#{@brpm_url}/#{add_token(path)}", data, options)
  end

  def brpm_delete(path, options = {})
    Rest.delete("#{@brpm_url}/#{add_token(path)}", options)
  end
end


