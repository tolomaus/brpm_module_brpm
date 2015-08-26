require_relative "spec_helper"

describe 'select application version' do
  before(:all) do
    setup_brpm_auto
  end

  before(:each) do
    cleanup_request_params
    cleanup_version_tags_for_app("E-Finance")
  end

  describe '' do
    it 'should store the selected application version in the request_params and create version tags' do
      params = get_default_params
      params["application"] = 'E-Finance'
      params["application_version"] = '1.0.0'

      BrpmScriptExecutor.execute_automation_script("brpm_module_brpm", "select_application_version", params)

      expect(BrpmAuto.request_params.has_key?("application_version"))
      expect(BrpmAuto.request_params["application_version"]).to eq("1.0.0")

      version_tag = @brpm_rest_client.get_version_tag("E-Finance","EF - Java calculation engine", "development", "1.0.0")
      expect(version_tag).not_to be_nil
    end
  end

  describe 'with auto_created request_param set' do
    it 'should NOT store the selected application version in the request_params but still create version tags' do
      BrpmAuto.request_params["auto_created"] = true
      BrpmAuto.request_params["application_version"] = "2.0.0"

      params = get_default_params
      params["application"] = 'E-Finance'
      params["application_version"] = '1.0.0'

      BrpmScriptExecutor.execute_automation_script("brpm_module_brpm", "select_application_version", params)

      expect(BrpmAuto.request_params.has_key?("application_version"))
      expect(BrpmAuto.request_params["application_version"]).to eq("2.0.0")

      version_tag = @brpm_rest_client.get_version_tag("E-Finance","EF - Java calculation engine", "development", "2.0.0")
      expect(version_tag).not_to be_nil
    end
  end
end