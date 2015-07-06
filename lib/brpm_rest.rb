
# Base class for rest interactions
#  optimized for rest calls to BRPM
class BrpmRest

  # Initialize an instance of the brpmrest class
  #
  # ==== Attributes
  #
  # * +base_url+ - base url for rest calls
  # * +options+ - hash of options, includes:
  #   token: a rest token for brpm
  #   output_file: file for BrpmAuto.log results (usually @p.SS_output_file)
  #
  def initialize(base_url, options = {}, compat_options = {})
    self.extend Utilities
    if options.has_key?("SS_output_dir")
      BrpmAuto.log "Load for this class has changed, no longer necessary to send params as 2nd argument"
      options = compat_options 
    end
    @base_url = base_url
    token = defined?(Token) ? Token : ""
    @token = get_option(options, "token", token)
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
    url = rest_url(model_name, model_id) if get_option(options, "filters") == ""
    url = rest_url(model_name, nil, options["filters"]) if get_option(options, "filters") != ""
    result = Rest.rest_call(url, "get", options)
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
    url = rest_url(model_name, model_id)
    options["data"] = data
    result = Rest.rest_call(url, "put", options)
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
    url = rest_url(model_name)
    result = Rest.rest_call(url, "post", options)
    result
  end
  
  # Sets the token for brpm rest calls
  #
  # ==== Attributes
  #
  # * +token+ - rest token
  #
  def set_token(token)
    @token = token
  end

  # Takes an array of version tag info and creates the version tags
  #
  # ==== Attributes
  #
  # * +tag_info+ - an array of hashes
  # ex: [{ "application" => "app1", "component" => "database", "name" => "1.2.1", "artifact_url" => "file:///home/brady/stuff"}]
  # * +options+ - a hash of options passed to the rest call
  #
  # ==== Returns
  #
  # * a hash of the command output
  def create_version_tags(tag_info, options = {})
    # Meant to be called after importing a spreadsheet of versions
    results = {"status" => "ERROR", "message" => "", "data" => []}
    message = "Processing tags: #{tag_info.size.to_s} to do\n"
    version_tag = { "name" => "", "artifact_url" => "", "find_application" => "", "find_component" => "", "active" => true}
    tag_info.each do |v_tag|
      if v_tag.has_key?("name")
        version_tag["find_application"] = v_tag["application"]
        version_tag["find_component"] = v_tag["component"]
        version_tag["name"] = v_tag["name"]
        version_tag["artifact_url"] = v_tag["artifact_url"]
        message += "adding #{v_tag["name"]} to #{v_tag["component"]}"
        result = create("version_tags", {"version_tag" => version_tag}, options)
        message += ", Status: #{result["status"]}\n"
        results["data"] << result["data"]
        results["status"] = result["status"]
      else
        message += "bad record: #{v_tag.inspect}\n"
      end
    end
    results["message"] = message
    results
  end

  # Queries RPM for a version by name
  #
  # ==== Attributes
  #
  # * +name+ - a version name
  #
  # ==== Returns
  #
  # * an array of matching version objects or "ERROR" if not found
  #
  def version_tag_query(name)
    result = "ERROR"
    result = get("version_tags",nil,{"filters" => "filters[name]=#{url_encode(name)}", "suppress_errors" => true})
    if result["status"] == "success"
      BrpmAuto.log "Tag Exists?: #{@base_url}\nResult: #{result["data"].inspect}"
      result = result["data"]
    else
      BrpmAuto.log "No version tags found"
      result = []
    end
    result
  end

  # Takes a version name and assigns it to the steps in a request
  # === skips steps where the version does not exist
  # ==== Attributes
  #
  # * +version+ - name of a version
  # * +steps+ - an array of steps (returned from rest call to requests)
  # * +options+ - hash of options passed to rest object e.g. {"verbose" => "yes"}
  #
  # ==== Returns
  #
  # * hash {"status" => success or ERROR, "rest_result" => [] array of rest responses
  #
  def assign_version_to_steps(version, steps, options = {})
    result = {"status" => "ERROR - failed to update steps", "rest_result" => []}
    components = steps.map{|l| l["component_name"]}.uniq
    version_tags = version_tag_query(version)
    return "ERROR no version tags for #{version}" if version_tags.is_a?(String) && version_tags.start_with?("ERROR")
    components.reject{|l| l.nil? }.each do |component|
      comp_steps = steps_with_matching_component(steps, component)
      BrpmAuto.log "Comp: #{component}, steps: #{comp_steps.size == 0 ? "no steps" : comp_steps.map{|l| l["name"] }.join(",") }"
      version_tag_id = "0"
      version_tags.each{|k| version_tag_id = k["id"] if k["installed_component_id"] == comp_steps[0]["installed_component_id"] }
      if version_tag_id == "0"
        BrpmAuto.log "No version_tag for component: #{component}"
      else
        BrpmAuto.log "Tag exists for component"
        comp_steps.each do |step|      
          step_data = {"version_tag_id" => version_tag_id, "component_version" => version}
          rest_result = update("steps", step["id"], step_data, options)
          if rest_result["status"] == "success"
            BrpmAuto.log "Updating step: #{step["id"]}\nResult: #{rest_result["data"].inspect}"
            result["status"] = "success"
          end
          result["rest_result"] << rest_result.inspect
        end
      end
    end
    result
  end

  # Takes an array of step objects and a component and returns the steps that match
  #
  # ==== Attributes
  #
  # * +steps+ - an array of steps (returned from rest call to requests)
  # * +comp+ - a component name
  #
  # ==== Returns
  #
  # * array of the steps that match
  def steps_with_matching_component(steps, comp)
    result = []
    steps.each do |step|
      result << step if !step["installed_component_id"].nil? && comp == step["component_name"]
    end
    result
  end
  
  # Takes a request_id and monitors status until a condition is met
  #
  # ==== Attributes
  #
  # * +request_id+ - id of the calling request
  # * +target_state+ - state to watch request or step for (default = complete)
  # * +options+ - a hash of options, includes:
  #    +monitor_step_name+ - this monitor whether a specific step has reached the target state
  #    +max_time+ - maximum time in minutes to wait (default = 15)
  #    +interval+ - interval in seconds between checks (default = 15)
  #    +verbose+ - passed to rest call for verbose output (true/false)
  #
  # ==== Returns
  #
  # * array of the steps that match
  def monitor_request(request_id, target_state = "complete", options = {})
    states = ["created","planned","started","problem","hold","complete"]
    max_time = get_option(options, "max_time", 15).to_i
    max_time = max_time * 60 # seconds = 15 minutes
    monitor_step_name = get_option(options, "monitor_step_name", "none")
    seed_interval = get_option(options, "interval", 15) #seconds
    verbose = get_option(options, "verbose")
    verbose = "no" unless verbose == "yes"
    raise "Command_Failed: bad request_id" if !(request_id.to_i > 0)
    raise "Command_Failed: state not allowed, choose from [#{states.join(",")}]" if !states.include?(target_state)
    BrpmAuto.message_box("Montoring Request: #{request_id}","sep")
    req_status = "none"
    start_time = Time.now
    elapsed = 0
    until (elapsed > max_time || req_status == target_state)
      rest_result = get("requests", request_id, {"verbose" => verbose})
      raise "Command_Failed: Request not found" if rest_result["status"] == "ERROR"
      if monitor_step_name == "none"
        req_status = rest_result["data"]["aasm_state"]
      else
        found = false
        i_pos = rest_result["data"]["steps"].map{|l| l["name"]}.index(monitor_step_name)
        raise "Command_Failed: Step name [#{monitor_step_name}] not found" if i_pos.nil?
        req_status = rest_result["data"]["steps"][i_pos]["aasm_state"]
      end
      if req_status == target_state
        break
      else
        BrpmAuto.log "\tWaiting(#{elapsed.floor.to_s}) - Current status: #{req_status}"
        sleep(checking_interval)
        elapsed = Time.now - start_time
      end
    end
    if req_status == target_state
      req_status =  "Success test, looking for #{target_state}: Success!"
    else
      if elapsed > max_time
        req_status =  "Command_Failed: Max time: #{max_time}(secs) reached.  Status is: #{req_status}, looking for: #{target_state}"
      else
        req_status = "REST call generated bad data, Status is: #{req_status}, looking for: #{target_state}"
      end
    end
    req_status
  end
  
  def checking_interval(interval, total_time)
    if (total_time/interval).to_i > 50
      interval = interval * 30 
    elsif (total_time/interval).to_i > 20
      interval = interval * 10 
    elsif (total_time/interval).to_i > 15
      interval = interval * 6 
    elsif (total_time/interval).to_i > 10
      interval = interval * 4 
    elsif (total_time/interval).to_i > 5
      interval = interval * 2 
    end
    interval
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
  def notify(step_id, body, subject = "Mail from automation")
    url = "#{@base_url}/v1/steps/#{step_id}/notify?token=#{@token}"
    data = {"filters"=>{"notify"=>{"body"=> body, "subject"=> subject}}}
    result = Rest.rest_call(url, "get", {"data" => data})
  end

  private
  
  def rest_url(model_name, id = nil, filters = nil)
    url = "#{@base_url}/v1/#{model_name}#{id == nil ? "" : "/#{id}" }"
    url += "?#{filters}&token=#{@token}" if filters
    url += "?token=#{@token}" unless filters
    url
  end

end

