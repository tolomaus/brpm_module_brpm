require_relative "../spec_helper"

describe 'List items REST API' do
  before(:all) do
    setup_brpm_auto
  end

  it 'should create, read, update and delete a list item' do
    list_item = {}
    list_item["list_id"] = 24 # AutomationCategory
    list_item["value_text"] = "MyAutomationCategory"
    list_item = @brpm_rest_client.create_list_item_from_hash(list_item)

    expect(list_item["list"]["id"]).to eq(24)
    expect(list_item["value_text"]).to eq("MyAutomationCategory")

    list_item = @brpm_rest_client.get_list_item_by_name("MyAutomationCategory")

    expect(list_item["list"]["id"]).to eq(24)
    expect(list_item["value_text"]).to eq("MyAutomationCategory")

    list_item["value_text"] += " - UPDATED"
    list_item = @brpm_rest_client.update_list_item_from_hash(list_item)

    expect(list_item["list"]["id"]).to eq(24)
    expect(list_item["value_text"]).to eq("MyAutomationCategory - UPDATED")
  end
end

