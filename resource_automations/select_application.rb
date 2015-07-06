def execute_script(params, parent_id, offset, max_records)
  brpm_rest_client = BrpmRestClient.new

  BrpmAuto.log "Finding all applications..."
  apps = brpm_rest_client.get_apps()

  apps = apps.sort_by { |app| app["name"] }

  BrpmAuto.log "Adding the #{apps.count} found applications to the list..."
  results = []
  apps.each do |app|
    results << { app["name"] => app["id"].to_i }
  end

  results
end