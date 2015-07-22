require_relative "../spec_helper"

describe 'List items REST API' do
  before(:all) do
    setup_brpm_auto

    list_items = @brpm_rest_client.get_list_items_by({:value_text => "MyAutomationCategory"})
    list_items.each do |list_item|
      @brpm_rest_client.archive_list_item(list_item["id"])
      @brpm_rest_client.delete_list_item(list_item["id"])
    end
  end

  it 'should create, read, update and delete a list item' do
    list_id = @brpm_rest_client.get_list_by_name("AutomationCategory")["id"]

    list_item = {}
    list_item["list_id"] = list_id
    list_item["value_text"] = "MyAutomationCategory"
    list_item = @brpm_rest_client.create_list_item_from_hash(list_item)

    expect(list_item["list"]["id"]).to eq(list_id)
    expect(list_item["value_text"]).to eq("MyAutomationCategory")

    list_item = @brpm_rest_client.get_list_item_by_id(list_item["id"])

    expect(list_item["list"]["id"]).to eq(list_id)
    expect(list_item["value_text"]).to eq("MyAutomationCategory")

    list_item = @brpm_rest_client.get_list_item_by_name("AutomationCategory", "MyAutomationCategory")

    expect(list_item["list"]["id"]).to eq(list_id)
    expect(list_item["value_text"]).to eq("MyAutomationCategory")

    list_item["value_text"] += " - UPDATED"
    list_item = @brpm_rest_client.update_list_item_from_hash(list_item)

    expect(list_item["list"]["id"]).to eq(list_id)
    expect(list_item["value_text"]).to eq("MyAutomationCategory - UPDATED")

    @brpm_rest_client.archive_list_item(list_item["id"])

    @brpm_rest_client.delete_list_item(list_item["id"])

    list_item = @brpm_rest_client.get_list_item_by_name("AutomationCategory", "MyAutomationCategory")
    expect(list_item).to be_nil
  end
end

