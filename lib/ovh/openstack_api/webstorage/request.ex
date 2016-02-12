defmodule ExOvh.Ovh.OpenstackApi.Webstorage.Request do
  alias ExOvh.Ovh.OpenstackApi.Webstorage.Auth
  alias ExOvh.Ovh.OvhApi.Cache, as: ClientCache


  @spec request(client :: atom, query :: ExOvh.Client.query_t, service :: String.t)
               :: {:ok, ExOvh.Client.response_t} | {:error, ExOvh.Client.response_t}
  def request(client, {method, uri, params} = query, service) do
    LoggingUtils.log_mod_func_line(__ENV__, :debug)

    {method, uri, options} = Auth.prepare_request(client, query, service)
    resp = HTTPotion.request(method, uri, options)
    resp =
    %{
      body: resp.body |> Poison.decode!(),
      headers: resp.headers,
      status_code: resp.status_code
    }

    if resp.status_code >= 100 and resp.status_code < 300 do
     {:ok, resp}
    else
     {:error, resp}
    end
  end


end
