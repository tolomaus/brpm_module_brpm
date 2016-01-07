params = BrpmAuto.params

brpm_rest_client = BrpmRestClient.new

BrpmAuto.log "Getting all environments of application #{params["application"]} ..."
environments = brpm_rest_client.get_environments_of_application(params["application"])

environments.each do |environment|
  BrpmAuto.log "Creating the version tag for version #{params["component_version"]} of application #{params["application"]} and component #{params["component"]} in environment #{environment["name"]}..."
  environment = brpm_rest_client.create_version_tag(params["application"], params["component"], environment["name"], params["component_version"])
end
