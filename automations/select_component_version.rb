if BrpmAuto.request_params["auto_created"]
  BrpmAuto.log "The request was created in an automated way, not overriding the request params from the manual input step."
else
  params = BrpmAuto.params
  component_versions = BrpmAuto.request_params["component_versions"] || {}

  BrpmAuto.log "Adding component version '#{params["component"]}' '#{params["component_version"]}' to the request_params..."
  component_versions[params["component"]] = params["component_version"]

  BrpmAuto.request_params["component_versions"] = component_versions
end

