def execute_script(params, parent_id, offset, max_records)
  brpm_rest_client = BrpmRestClient.new

  if parent_id.nil?
    BrpmAuto.log "Finding all requests in the same stage as the current request (plan: #{params["request_plan"]} (id: #{params["request_plan_id"]}), stage: #{params["request_plan_stage"]}) ..."
    requests = brpm_rest_client.get_requests_by_plan_id_and_stage_name(params["request_plan_id"], params["request_plan_stage"])

    requests = requests.sort_by { |request| request["number"] }

    results = []
    requests.each do |request|
      unless request["number"] == params["request_number"]
        results << { :title => "#{request["number"]} - #{request["name"]}", :key => request["id"], :isFolder => true, :hasChild => true, :hideCheckbox => true}
      end
    end

    results
  else
    BrpmAuto.log "Finding all steps in the request with id #{parent_id} ..."
    request = brpm_rest_client.get_request_by_id(parent_id)

    return if request.nil?

    steps = request["steps"].sort_by { |step| step["number"].to_i }

    results = []
    steps.each do |step|
      results << { :title => "#{step["position"]} - #{step["name"]}", :key => "#{parent_id}|#{step["id"]}", :isFolder => false, :hasChild => false, :hideCheckbox => false}
    end

    results
  end
end