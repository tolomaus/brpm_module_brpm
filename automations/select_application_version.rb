brpm_rest_client = BrpmRestClient.new

if BrpmAuto.request_params["auto_created"]
  BrpmAuto.log "The request was created in an automated way, not overriding the request params from the manual input step."
  application_version = BrpmAuto.request_params["application_version"]
else
  BrpmAuto.log "Storing the input parameters ..."
  BrpmAuto.request_params["application_version"] = BrpmAuto.params["application_version"]

  application_version = BrpmAuto.params["application_version"]
end

BrpmAuto.log "Creating version tags for all components..."
application = brpm_rest_client.get_app_by_name(BrpmAuto.params["application"])

application["components"].each do |component|
  application["environments"].each do |environment|
    brpm_rest_client.create_version_tag(application["name"], component["name"], environment["name"], application_version)
  end
end


