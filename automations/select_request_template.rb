params = BrpmAuto.params
request_params = BrpmAuto.request_params

BrpmAuto.log "Adding request template '#{params["request_template_id"]}' to the request_params..."
request_params["request_template_id"] = params["request_template_id"]

