require_relative "../spec_helper"

describe 'Lists REST API' do
  before(:all) do
    setup_brpm_auto
  end

  it 'should create, read, update and delete a list' do
    list = {}
    list["name"] = "MyList"
    list = @brpm_rest_client.create_list_from_hash(list)

    expect(list["name"]).to eq("MyList")

    list = @brpm_rest_client.get_list_by_id(list["id"])

    expect(list["name"]).to eq("MyList")

    list = @brpm_rest_client.get_list_by_name("MyList")

    expect(list["name"]).to eq("MyList")

    list["name"] += " - UPDATED"
    list = @brpm_rest_client.update_list_from_hash(list)

    expect(list["name"]).to eq("MyList - UPDATED")

    @brpm_rest_client.archive_list(list["id"])

    @brpm_rest_client.delete_list(list["id"])

    list = @brpm_rest_client.get_list_by_name("MyList")
    expect(list).to be_nil
  end
end

