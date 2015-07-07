require_relative "spec_helper"

describe 'create request' do
  before(:all) do
    setup_brpm_auto
  end

  before(:each) do
    cleanup_requests_and_plans_for_app("E-Finance")
  end

  describe 'from request template by name' do
    it 'should create a request from template' do
      request_params = {}
      request_params["application_version"] = '1.0.0'
      request_params["template_name"] = 'Deploy E-Finance'
      set_request_params(request_params)

      params = get_default_params
      params["application"] = 'E-Finance'
      params["target_environment_id"] = '5' #test
      params["release_request_template_name"] = 'Release E-Finance'
      params["execute_target_request"] = 'No'

      BrpmScriptExecutor.execute_automation_script_from_gem("brpm_module_brpm", "create_request", params)

      request = @brpm_rest_client.get_request_by_id(BrpmAuto.request_params["target_request_id"])

      expect(request["aasm_state"]).to eq("created")
      expect(request).not_to have_key("plan_member")
    end
  end

  describe 'from request template by id' do
    it 'should create a request from template' do
      request_params = {}
      request_params["application_version"] = '1.0.0'
      request_params["request_template_id"] = '1' #Deploy E-Finance
      set_request_params(request_params)

      params = get_default_params
      params["application"] = 'E-Finance'
      params["target_environment_id"] = '5' #test
      params["release_request_template_name"] = 'Release E-Finance'
      params["execute_target_request"] = 'No'

      BrpmScriptExecutor.execute_automation_script_from_gem("brpm_module_brpm", "create_request", params)

      request = @brpm_rest_client.get_request_by_id(BrpmAuto.request_params["target_request_id"])

      expect(request["aasm_state"]).to eq("created")
      expect(request).not_to have_key("plan_member")
    end
  end

  describe 'from request template for plan and stage' do
    it 'should create a request from template' do
      plan = @brpm_rest_client.create_plan("E-Finance Release Plan", "E-Finance Release Plan v1.0.0")

      request_params = {}
      request_params["application_version"] = '1.0.0'
      request_params["template_name"] = 'Deploy E-Finance'
      set_request_params(request_params)

      params = get_default_params
      params["application"] = 'E-Finance'
      params["target_environment_id"] = '5' #test
      params["release_request_template_name"] = 'Release E-Finance'
      params["request_plan_id"] = plan["id"].to_s
      params["target_stage"] = 'Test'
      params["execute_target_request"] = 'No'

      BrpmScriptExecutor.execute_automation_script_from_gem("brpm_module_brpm", "create_request", params)

      request = @brpm_rest_client.get_request_by_id(BrpmAuto.request_params["target_request_id"])

      expect(request["aasm_state"]).to eq("created")
      expect(request).to have_key("plan_member")
      expect(request["plan_member"]["plan"]["id"]).to eq(plan["id"])
      expect(request["plan_member"]["stage"]["name"]).to eq("Test")
    end
  end
end

