defmodule ExOvh.Auth.Openstack.Swift.Cache.Cloudstorage do
  @moduledoc :false
  alias Openstex.Helpers.V2.Keystone.Identity

  @doc :false
  @spec create_identity({atom, atom}, atom) :: Identity.t | no_return
  def create_identity({ovh_client, swift_client}, config) do
    tenant_id = Keyword.fetch!(config, :tenant_id)
    user_id = Keyword.get(config, :user_id, :nil)
    region = Keyword.get(config, :region, "SBG1")

    user_id =
    case user_id do
      :nil ->
        user = ExOvh.Ovh.V1.Cloud.Query.get_users(tenant_id)
        |> ovh_client.request!()
        |> Map.get(:body)
        |> Enum.find(:nil,
          fn(user) -> %{"description" => "ex_ovh"} = user end
        )
        if user == :nil do
          # create user for "ex_ovh" description
          ExOvh.Ovh.V1.Cloud.Query.create_user(tenant_id, "ex_ovh")
          |> ovh_client.request!()
          |> Map.get("id")
        else
          user["id"]
        end
      user_id -> user_id
    end

    resp = ExOvh.Ovh.V1.Cloud.Query.regenerate_credentials(tenant_id, user_id) |> ovh_client.request!()
    password = resp.body["password"]
    username = resp.body["username"]
    endpoint = config[:endpoint] || "https://auth.cloud.ovh.net/v2.0"

    # make sure the regenerate credentials (in the external ovh api) had a chance to take effect
    :timer.sleep(1000)

    identity = Module.concat(swift_client, Helpers.Keystone).authenticate!(endpoint, username, password, [tenant_id: tenant_id])
  end

#    token = Openstex.Keystone.V2.Query.get_token(endpoint, username, password)
#    |> client.request!()
#    |> Map.get(:body)
#    |> Map.get("access")
#    |> Map.get("token")
#    |> Map.get("id")

#    identity = Openstex.Keystone.V2.Query.get_identity(token, endpoint, tenant)
#    |> client.request!()
#    |> Map.get(:body)

end