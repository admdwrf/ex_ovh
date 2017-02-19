defmodule ExOvh.Query.V1.Webstorage do
  @moduledoc ~s"""

  ***NOTE:*** This is a deprecated service!!!

  Helper functions for building queries directed at the `/cdn/webstorage` part of the [OVH API](https://api.ovh.com/console/).

  ## Functions Summary

  | Function | Description | OVH API call |
  |---|---|---|
  | `get_services/0` | <small>Get a list of all webstorage cdn services.</small> | <sub><sup>GET /v1/​cdn/webstorage</sup></sub> |
  | `get_service/1` | <small>Get the domain, server and storage limits for a specific webstorage cdn service</small> | <sub><sup>GET /v1/​cdn/webstorage​/{serviceName}</sup></sub> |
  | `get_service_info/1` | <small>Get a administrative details for a specific webstorage cdn service</small> | <sub><sup>GET /v1/​cdn/webstorage​/{serviceName}/serviceInfos</sup></sub> |
  | `get_service_stats/2`  | <small>Get statistics for a specific webstorage cdn service</small> | <sub><sup>GET /v1/​cdn/webstorage​/{serviceName}/statistics</sup></sub> |
  | `get_credentials/1` | <small>Get credentials for using the swift compliant api</small> | <sub><sup>GET /v1/​cdn/webstorage​/{serviceName}/statistics</sup></sub> |


  ## Example

      ExOvh.Query.V1.Webstorage.get_services() |> ExOvh.request()
  """
  alias ExOvh.HttpQuery
  alias ExOvh.Transformation.Uri



  @doc ~s"""
  ​Get a list of all webstorage cdn services available for the client account

  ## Api call

      GET /v1/​cdn/webstorage

  ## Example

      ExOvh.Query.V1.Webstorage.get_services() |> ExOvh.request()
  """
  @spec get_services() :: HttpQuery.t
  def get_services() do
    %HttpQuery{
          method: :get,
          uri: "/cdn/webstorage"
          }
  end



  @doc ~s"""
  Get the domain, server and storage limits for a specific webstorage cdn service

  ## Api call

      GET /v1/​cdn/webstorage​/{serviceName}

  ## Arguments

  - `service_name`: Name of the Webstorage CDN service - assigned by OVH.

  ## Example

      alias ExOvh.Query.V1.Webstorage
      service_name = "cdnwebstorage-????"
      query = Query.get_service(service_name)
      {:ok, resp} = ExOvh.Ovh.request(query)
      %{
        "domain" => domain,
        "storageLimit => storage_limit,
        "server" => server
       } = resp.body
  """
  @spec get_service(String.t) :: HttpQuery.t
  def get_service(service_name) do
   %HttpQuery{
          method: :get,
          uri: "/cdn/webstorage/#{service_name}"
          }
  end



  @doc ~s"""
  Get a administrative details for a specific webstorage cdn service

  ## Api call

      GET /v1/​cdn/webstorage​/{serviceName}/serviceInfos

  ## Arguments

  - `service_name`: Name of the Webstorage CDN service - assigned by OVH.

  ## Example

      alias ExOvh.Query.V1.Webstorage
      service_name = "cdnwebstorage-????"
      Query.get_service_info(service_name)
      {:ok, resp} = ExOvh.Ovh.request(query)
  """
  @spec get_service_info(String.t) :: HttpQuery.t
  def get_service_info(service_name) do
    %HttpQuery{
      method: :get,
      uri: "/cdn/webstorage/#{service_name}/serviceInfos"
      }
  end



  @doc ~s"""
  Get statistics for a specific webstorage cdn service

  ## Api call

      GET /v1/​cdn/webstorage​/{serviceName}/statistics

  ## Arguments

  - `service_name`: Name of the Webstorage CDN service - assigned by OVH.
  - `options`:
      - `period can be "month", "week" or "day"`
      - `type can be "backend", "quota" or "cdn"`

  ## Example

      alias ExOvh.Query.V1.Webstorage
      service_name = "cdnwebstorage-????"
      query = Query.get_service_stats(service_name, [period: "month", type: "backend"])
      {:ok, resp} = ExOvh.Ovh.request(query)
  """
  @spec get_service_stats(String.t, Keyword.t) :: HttpQuery.t
  def get_service_stats(service_name, opts \\ []) do
    period = Keyword.get(opts, "period", "month")
    type = Keyword.get(opts, "type", "cdn")
    %HttpQuery{
          method: :get,
          uri: "/cdn/webstorage/#{service_name}/statistics"
          }
    |> Uri.add_query_string(%{"period" => period,"type" => type})
  end


  @doc ~s"""
  Get credentials for using the swift compliant api

  ## Api call

      GET /v1/​cdn/webstorage​/{serviceName}/credentials

  ## Arguments

  - `service_name`: Name of the Webstorage CDN service - assigned by OVH.

  ## Example

      alias ExOvh.Query.V1.Webstorage
      service_name = "cdnwebstorage-????"
      query = Query.get_webstorage_credentials(service_name)
      {:ok, resp} = ExOvh.Ovh.request(query)
  """
  @spec get_credentials(String.t) :: ExOvh.Query.Ovh.t
  def get_credentials(service_name) do
    %HttpQuery{
          method: :get,
          uri: "/cdn/webstorage/#{service_name}/credentials"
          }
  end


end
