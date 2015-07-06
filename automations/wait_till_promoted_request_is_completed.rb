brpm_rest_client = BrpmRestClient.new
request_params = BrpmAuto.request_params

BrpmAuto.log "Getting the request ..."
request = brpm_rest_client.get_request_by_id(request_params["promoted_request_id"])

BrpmAuto.log "Waiting until the request has finished ..."
brpm_rest_client.monitor_request(request["id"], { :max_time => 60 * 24})

