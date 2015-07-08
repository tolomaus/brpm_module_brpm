#!/bin/bash

# ASSUMPTION: this script should be executed from the root direcory of the framework

if [ -z "$BRPM_HOME" ]; then
    echo "BRPM_HOME is not set (e.g. /opt/bmc/RLM). Aborting the installation."
    exit 1
fi

. $BRPM_HOME/bin/setenv.sh

jruby <<-EORUBY
require "modules/framework/brpm_script_executor"

params = {}
params["application_name"] = "$APPLICATION_NAME"
params["application_version"] = "$APPLICATION_VERSION"

params["ef_net_version"] = "$EF_NET_VERSION"
params["ef_java_version"] = "$EF_JAVA_VERSION"

params["release_request_template_name"] = "$RELEASE_REQUEST_TEMPLATE_NAME"
params["release_plan_template_name"] = "$RELEASE_PLAN_TEMPLATE_NAME" unless "$RELEASE_PLAN_TEMPLATE_NAME".empty?
params["release_plan_name"] = "$RELEASE_PLAN_NAME" unless "$RELEASE_PLAN_NAME".empty?

params["brpm_url"] = "http://$BRPM_HOST:$BRPM_PORT/brpm"
params["brpm_api_token"] = "$BRPM_TOKEN"

params["log_file"] = "$LOG_FILE"
params["also_log_to_console"] = "true"

BrpmScriptExecutor.execute_automation_script("brpm_module_brpm", "create_release_request", params)
EORUBY

