require_relative "spec_helper"

describe 'create release request' do
  before(:all) do
    setup_brpm_auto
  end

  before(:each) do
    cleanup_requests_and_plans_for_app("E-Finance")
  end

  describe '' do
    it 'should create a request from template' do
      params = get_default_params
      params["application_name"] = 'E-Finance'
      params["application_version"] = '1.0.0'
      params["release_request_template_name"] = 'Release E-Finance'

      BrpmScriptExecutor.execute_automation_script("brpm", "create_release_request", params)

      request = @brpm_rest_client.get_request_by_id(BrpmAuto.params["result"]["request_id"])

      expect(request["aasm_state"]).to eq("started")
      expect(request).not_to have_key("plan_member")
    end
  end

  describe 'in new plan' do
    it 'should create a plan from template and a request from template in that plan' do
      params = get_default_params
      params["application_name"] = 'E-Finance'
      params["application_version"] = '1.0.1'
      params["release_request_template_name"] = 'Release E-Finance'
      params["release_plan_template_name"] = 'E-Finance Release Plan'

      BrpmScriptExecutor.execute_automation_script("brpm", "create_release_request", params)

      request = @brpm_rest_client.get_request_by_id(BrpmAuto.params["result"]["request_id"])

      expect(request["aasm_state"]).to eq("started")
      expect(request).to have_key("plan_member")
      expect(request["plan_member"]["plan"]["id"]).not_to be_nil
    end
  end

  describe 'in existing plan' do
    it 'should create a request from template in the plan' do
      plan = @brpm_rest_client.create_plan("E-Finance Release Plan", "E-Finance Release Plan v1.0.2")

      params = get_default_params
      params["application_name"] = 'E-Finance'
      params["application_version"] = '1.0.2'
      params["release_request_template_name"] = 'Release E-Finance'
      params["release_plan_name"] = 'E-Finance Release Plan v1.0.2'

      BrpmScriptExecutor.execute_automation_script("brpm", "create_release_request", params)

      request = @brpm_rest_client.get_request_by_id(BrpmAuto.params["result"]["request_id"])

      expect(request["aasm_state"]).to eq("started")
      expect(request).to have_key("plan_member")
      expect(request["plan_member"]["plan"]["id"]).to eq(plan["id"])
    end
  end
end

