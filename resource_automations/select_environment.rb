def execute_script(params, parent_id, offset, max_records)
  brpm_rest_client = BrpmRestClient.new

  BrpmAuto.log "Finding all environments for application #{params["application"]}..."
  environments = brpm_rest_client.get_environments_of_application(params["application"])

  BrpmAuto.log "Adding the #{environments.count} found environments to the list..."
  results = []
  environments.each do |environment|
    results << { environment["name"] => environment["id"].to_i }
  end

  results
end