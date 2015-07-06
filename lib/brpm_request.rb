# Class for interacting with requests
class BrpmRequest < BrpmRest

  # Initializes an instance of the class
  #
  # ==== Attributes
  #
  # * +id+ - id of the request to work with
  # * +base_url+ - url of brpm server
  # * +options+ - hash of options (see Rest.rest_call for description)
  #
  def initialize(id, base_url, options = {}, compat_options = {})
    if options.has_key?("SS_output_dir")
      BrpmAuto.log "Load for this class has changed, no longer necessary to send params as 2nd argument"
      options = compat_options 
    end
    @id = id
    response = BrpmAuto.get("requests", @id)
    @request = response["data"]
  end
  
  # Gets a list of requests based on a filter
  #
  # ==== Attributes
  #
  # * +filter_param+ - filter for requests there are extensive filter options
  #   ex: filters["planned_end_date"]>2013-04-22
  #
  # ==== Returns
  #
  # * array of request hashs
  def get_list(filter_param)
    response = Rest.rest_call(rest_url("requests", @id, filter_param), "get")
    @request = response["data"]
  end
  
  # Returns the steps for the request
  #
  # ==== Returns
  #
  # * hash of steps from request
  def steps
    steps = @request["steps"]
  end
  
  # Updates the aasm state of the request
  #
  # ==== Attributes
  #
  # * +aasm_event+ - event name [plan, start, problem, resolve]
  #
  # ==== Returns
  #
  # * hash of uppdated request
  def update_state(aasm_event) 
    request_info = {"request" => {"aasm_event" => aasm_event }}
    result = update("requests", @id, request_info)    
  end
  
  # Provides a host status for the passed targets
  #
  # ==== Returns
  #
  # * hash of request
  def request
    @request
  end
  
  # Gets the app associated with the request
  #
  # ==== Returns
  #
  # * hash of app information
  def app
    @request["apps"].first
  end
  
  # Gets the installed_components associated with request application
  #
  # ==== Returns
  #
  # * hash of installed_components
  def installed_components
    return @installed_components if defined?(@installed_components)
    res = get("installed_components", nil, {"filters" => "filters[app_name]=#{url_encode(app["name"])}"})
    @installed_components = res["data"]
  end

  # Gets the components associated with request application
  #
  # ==== Returns
  #
  # * hash of components
  def app_components
    installed_components unless defined?(@installed_components)
    @installed_components.map{|l| l["application_component"]["component"]}.uniq
  end
  
  # Gets the components associated with request application
  #
  # ==== Returns
  #
  # * hash of components
  def app_environments
    installed_components unless defined?(@installed_components)
    @installed_components.map{|l| l["application_environment"]["environment"]}.uniq
  end

  # Gets the owner of the request
  #
  # ==== Returns
  #
  # * username of request owner
  def owner
    request["owner"]
  end

  # Gets the requestor of the request
  #
  # ==== Returns
  #
  # * username of requestor
  def requestor
    request["requestor"]
  end
  
  # Gets the plan of the request
  #
  # ==== Returns
  #
  # * hash of plan or nil if not part of a plan
  def plan
    return nil if request["plan_member"].nil?
    plan_id = request["plan_member"]["plan"]["id"]
    res = get("plans", plan_id)
  end
  
  # Gets the stage of the plan the request is in
  #
  # ==== Returns
  #
  # * hash of stage
  def stage
    return nil if request["plan_member"].nil?
    request["plan_member"]["stage"]
  end
  
  # Gets the routes available for the app/plan
  #
  # ==== Returns
  #
  # * array of hashes of plan routes
  def plan_routes
    return nil if request["plan_member"].nil?
    plan["plan_routes"]
  end

  # Gets the routes available for the app
  #
  # ==== Returns
  #
  # * array of hashes of routes
  def app_routes
    res = get("apps", app["id"])
    res["data"]["routes"]
  end

  # Gets the environments available for the route
  #
  # ==== Attributes
  #
  # * +route_id+ - id of the route
  #
  # ==== Returns
  #
  # * array of environments for the route
  def route_environments(route_id)
    # Returns environment list for a particular route
    envs = {}
    res = get("routes", route_id)
    res["data"]["route_gates"].each_with_index do |gate,idx|
      envs[gate["environment"]["name"]] = {"id" => gate["environment"]["id"], "position" => idx.to_s }
    end
    envs
  end

  # Gets the plan stages available for the plan
  #
  # ==== Returns
  #
  # * array of hashes of plan stages
  def plan_stages
    plan["plan_stages"]
  end
  
  # Gets the groups available
  #
  # ==== Returns
  #
  # * array of hashes of groups
  def groups
    result = get("groups")
  end
  

end

