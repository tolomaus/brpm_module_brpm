brpm_rest_client = BrpmRestClient.new
params = BrpmAuto.params

req_step = params["other_request_step"].split("|")
request_id = req_step[0].to_i
step_id = req_step[1].to_i

BrpmAuto.log "Monitoring step #{step_id} of request #{request_id} ..."
brpm_rest_client.monitor_request(request_id, { :monitor_step_id => step_id })


