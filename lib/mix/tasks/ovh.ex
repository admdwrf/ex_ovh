defmodule Mix.Tasks.Ovh do
  @shortdoc "Create a new application and new credentials for accessing ovh api"
  @moduledoc Module.concat(__MODULE__, Docs).moduledoc()
  use Mix.Task
  alias ExOvh.Defaults
  @default_headers [{"Content-Type", "application/json; charset=utf-8"}]
  @default_options [ timeout: 30000, recv_timeout: (60000 * 1) ]


  # Public


  def run(args) do
    opts_map = parse_args(args)
    IO.inspect(opts_map, pretty: :true)
    Mix.Shell.IO.info("")
    Mix.Shell.IO.info("The details in the map above will be used to create the ovh application.")
    Mix.Shell.IO.info("")
    if Mix.Shell.IO.yes?("Proceed?") do
      HTTPoison.start
      opts_map = parse_args(args)

      message = get_credentials(opts_map)
      |> remove_private()
      |> create_or_update_env_file()
      |> print_config()

      Mix.Shell.IO.info(message)
      Mix.Shell.IO.info("")
      Mix.Shell.IO.info("Update the environment variables and all is done here.")
      Mix.Shell.IO.info("")
      Mix.Shell.IO.info("For example: ")
      Mix.Shell.IO.info("")
      Mix.Shell.IO.info("source .env")
    end
  end


  ##########################
  # Private
  #########################


  defp parse_args(args) do
    {opts, _, _} = OptionParser.parse(args)
    {_opts, opts_map} = opts
    |> has_required_args()
    |> parsers_login()
    |> parsers_password()
    |> parsers_endpoint()
    |> parsers_api_version()
    |> parsers_redirect_uri()
    |> parsers_app_name()
    |> parsers_app_desc()
    |> parsers_access_rules()
    |> parsers_client_name()
    opts_map
  end


  defp has_required_args(opts) do
    login = Keyword.get(opts, :login, :nil)
    if login == :nil do
      raise "Task requires login argument"
    end
    password = Keyword.get(opts, :password, :nil)
    if password == :nil do
      raise "Task requires password argument"
    end
    {opts, %{}}
    application_name = Keyword.get(opts, :appname, :ex_ovh)
    if application_name == :nil do
      raise "Task requires appname argument"
    end
    {opts, %{}}
  end


  defp parsers_login({opts, acc}), do: {opts, Map.merge(acc, %{login: Keyword.fetch!(opts, :login)}) }
  defp parsers_password({opts, acc}), do: {opts, Map.merge(acc, %{ password: Keyword.fetch!(opts, :password)}) }
  # defp parsers_app_name({opts, acc}), do: {opts, Map.merge(acc, %{ application_name: Keyword.fetch!(opts, :appname)}) }
  defp parsers_endpoint({opts, acc}) do
    endpoint = Keyword.get(opts, :endpoint, :nil)
    endpoint =
    case endpoint do
      :nil -> "ovh-eu"
      _ -> endpoint
    end
    {opts, Map.merge(acc, %{ endpoint: endpoint }) }
  end
  defp parsers_api_version({opts, acc}) do
    api_version = Keyword.get(opts, :apiversion, :nil)
    api_version =
    case api_version do
      :nil -> "1.0"
      _ -> api_version
    end
    {opts, Map.merge(acc, %{ api_version: api_version }) }
  end
  defp parsers_redirect_uri({opts, acc}) do
    redirect_uri = Keyword.get(opts, :redirecturi, "")
    {opts, Map.merge(acc, %{ redirect_uri: redirect_uri }) }
  end
  defp parsers_client_name({opts, acc}) do
    client_name = Keyword.get(opts, :clientname, :nil)
    {opts, Map.merge(acc, %{ client_name: client_name }) }
  end
  defp parsers_app_name({opts, acc}) do
    application_name = Keyword.get(opts, :appname, :nil)
    application_name =
    case application_name do
      :nil -> "ex_ovh"
      _ -> application_name
    end
    {opts, Map.merge(acc, %{ application_name: application_name }) }
  end
  defp parsers_app_desc({opts, acc}) do
    application_description = Keyword.get(opts, :appdescription, :nil)
    application_description =
    case application_description do
      :nil -> "ex_ovh"
      _ -> application_description
    end
    {opts, Map.merge(acc, %{ application_description: application_description }) }
  end
  defp parsers_access_rules({opts, acc}) do
    access_rules = Keyword.get(opts, :accessrules, :nil)
    access_rules =
    if access_rules == :nil do
      Defaults.access_rules()
    else
      String.split(access_rules, "::")
      |> Enum.map(fn(method_rules) ->
        [method, paths] = String.split(method_rules, "-")
        {method, paths}
      end)
      |> Enum.reduce([], fn({method, concat_paths}, acc) ->
        paths = concat_paths
        |> String.lstrip(?[)
        |> String.strip(?]) #rstrip has a bug but fixed in master (01/02/2016)
        |> String.split(",")
        new_rules = Enum.filter_map(paths,
          fn(path) -> path !== "" end,
          fn(path) ->
          %{
            method: String.upcase(method),
            path: path
           }
        end)
        List.insert_at(acc, -1, new_rules)
      end)
      |> List.flatten()
    end
    {opts, Map.merge(acc, %{access_rules: access_rules}) }
  end


  defp get_app_create_page(opts_map) do
    Og.context(__ENV__, :debug)

    method = :get
    uri = Defaults.endpoints()[opts_map[:endpoint]] <> Defaults.create_app_uri_suffix()
    body = ""
    headers = []
    options = @default_options
    resp = HTTPoison.request!(method, uri, body, headers, options)
    Map.get(resp, :body)
  end


  defp get_create_app_inputs(resp_body) do
    Og.context(__ENV__, :debug)

    inputs = Floki.find(resp_body, "form input")
    |> List.flatten()
    if Enum.any?(inputs, fn(input) -> input == [] end), do: raise "Empty input found"
    inputs
  end


  defp build_app_request(inputs, %{login: login, password: password} = opts_map) do
    Og.context(__ENV__, :debug)

    {acc, _index, _max} =
    Enum.reduce(inputs, {"", 1, Enum.count(inputs)}, fn({"input", input, _}, acc) ->
      name = :proplists.get_value("name", input)
      value = ""
      case name do
        "nic" ->
          value = login
        "password" ->
          value = password
        "applicationName" ->
          value = opts_map.application_name
         "applicationDescription" ->
          value = opts_map.application_description
        _ ->
          raise "Unexpected input"
      end
      param =  name <> "=" <> value
      {acc, index, max} = acc
      if index == max do
        acc = acc <> param
      else
        acc = acc <> param <> "&"
      end
      {acc, index + 1, max}
    end)
    acc
  end


  defp send_app_request(req_body, opts_map) do
    Og.context(__ENV__, :debug)

    method = :post
    uri = Defaults.endpoints()[opts_map[:endpoint]] <> Defaults.create_app_uri_suffix()
    body = req_body
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    options = @default_options
    resp = HTTPoison.request!(method, uri, body, headers, options)

    # Error checking
    cond do
     String.contains?(resp.body, msg = "There is already an application with that name for that Account ID") ->
      raise(msg <> ", try removing the old application first using the ovh api console or just create a new one.")
     String.contains?(resp.body, msg = "Invalid account/password") ->
      raise(msg <> ", try adding '-ovh' to the end of the login")
     String.contains?(resp.body, "Application created") ->
      resp.body
     true ->
      raise "unknown error"
    end

  end


  defp get_application_secret(body), do: Map.get(extract(body), "secret")
  defp get_application_key(body), do: Map.get(extract(body), "key")
  defp get_application_name(body), do: Map.get(extract(body), "name")
  defp get_application_description(body), do: Map.get(extract(body), "description")
  defp extract(body) do
    Floki.find(body, "pre")
    |> Enum.map(fn({"pre", [], [val]}) -> val end)
    |> Enum.map(fn(ext) ->
        case ext do
          {key, _, [val]} ->
            {key, val}
          val when is_binary(val) ->
            if String.length(val) > 20 do
              {"secret", val}
            else
              {"key", val}
            end
        end
      end)
    |> Enum.into(%{})
  end


  defp get_consumer_key(%{access_rules: access_rules, redirect_uri: redirect_uri} = opts_map) do
    Og.context(__ENV__, :debug)

    method = :post
    uri = Defaults.endpoints()[opts_map[:endpoint]] <> opts_map[:api_version] <> Defaults.consumer_key_suffix()
    body = %{ accessRules: access_rules, redirection: redirect_uri } |> Poison.encode!()
    headers = Map.merge(Enum.into(@default_headers, %{}), Enum.into([{"X-Ovh-Application", opts_map[:application_key]}], %{})) |> Enum.into([])
    options = @default_options
    resp = HTTPoison.request!(method, uri, body, headers, options)

    body = Poison.decode!(Map.get(resp, :body))
    {Map.get(body, "consumerKey"), Map.get(body, "validationUrl")}
  end


  defp bind_consumer_key_to_app({ck, validation_url}, opts_map) do
    Og.context(__ENV__, :debug)

    method = :get
    uri = validation_url
    body = ""
    headers = []
    options = @default_options
    resp = HTTPoison.request!(method, uri, body, headers, options)

    Map.get(resp, :body)
    |> get_bind_ck_to_app_inputs()
    |> build_ck_binding_request(opts_map)
    |> send_ck_binding_request(validation_url, ck)
  end


  defp get_bind_ck_to_app_inputs(resp_body) do
    Og.context(__ENV__, :debug)

    inputs = Floki.find(resp_body, "form input") ++
    Floki.find(resp_body, "form select")
    |> List.flatten()
    |> Enum.filter(fn({_type, input, _options}) ->
      :proplists.get_value("name", input) !== "identifiant"
    end)
    if Enum.any?(inputs, fn(input) -> input == [] end), do: raise "Inputs should not be empty"
    inputs
  end


  defp build_ck_binding_request(inputs, %{login: login, password: password} = _opts_map) do
    Og.context(__ENV__, :debug)

    {acc, _index, _max} =
    Enum.reduce(inputs, {"", 1, Enum.count(inputs)}, fn({type, input, _options}, acc) ->
      {name_val, value} =
      cond do
        type == "input" &&  {"name", "credentialToken"} in input ->
          name_val = :proplists.get_value("name", input)
          value = :proplists.get_value("value", input)
          {name_val, value}
        type == "input" && {"type", "password"} in input && {"placeholder", "Password"} in input ->
          name_val = :proplists.get_value("name", input)
          value = password
          {name_val, value}
        type == "input" && {"type", "text"} in input && {"placeholder", "Account ID or email address"} in input ->
          name_val = :proplists.get_value("name", input)
          value = login
          {name_val, value}
        type == "select" && {"name", "duration"} in input ->
          name_val = :proplists.get_value("name", input)
          value = "0"
          {name_val, value}
        true ->
          raise "Unexpected input"
      end
      param =  name_val <> "=" <> value
      {acc, index, max} = acc
      if index == max do
        acc = acc <> param
      else
        acc = acc <> param <> "&"
      end
      {acc, index + 1, max}
    end)
    acc
  end


  defp send_ck_binding_request(req_body, validation_url, ck) do
    Og.context(__ENV__, :debug)

    method = :post
    uri = validation_url
    body = req_body
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    options = @default_options
    resp = HTTPoison.request!(method, uri, body, headers, options)

    error_msg1 = "Failed to bind the consumer token to the application. Please try to validate the consumer token manually at #{validation_url}"
    error_msg2 = "Invalid validity period entered for the consumer token. Please try to validate the consumer token manually at #{validation_url}"
    cond do
     String.contains?(resp.body, "Invalid validity") ->
      raise error_msg2
     String.contains?(resp.body, "The token is now valid, it can be used in the application") ->
      ck
    String.contains?(resp.body, "Your token is now valid, you can use it in your application") ->
      ck
    String.contains?(resp.body, "token is now valid") ->
      ck
     resp.status_code == 302 && (resp.headers |> Enum.into(%{}) |> Map.has_key?("Location")) ->
      ck  # presume the validation was successful if redirected to redirect uri
     true ->
      raise error_msg1
    end

  end


  defp get_credentials(opts_map) do
    Og.context(__ENV__, :debug)

    create_app_body = get_app_create_page(opts_map) |> get_create_app_inputs() |> build_app_request(opts_map) |> send_app_request(opts_map)
    opts_map = Map.merge(opts_map, %{
      application_key: get_application_key(create_app_body),
      application_secret: get_application_secret(create_app_body),
      application_name: get_application_name(create_app_body),
      application_description: get_application_description(create_app_body)
    })
    ck = get_consumer_key(opts_map) |> bind_consumer_key_to_app(opts_map)
    Map.merge(opts_map, %{ consumer_key: ck })
    |> Map.delete(:login) |> Map.delete(:password)
  end


  defp remove_private(opts_map) do
    opts_map |> Map.delete(:login) |> Map.delete(:password)
  end


  defp config_names(app_name, client_name) do
    Og.context(__ENV__, :debug)

    {config_header, mod_client_name} =
    case app_name do
      "ex_ovh" ->
        {
          ":" <> app_name,
          "EX_OVH_"
        }
      other ->
        client_name =
        case client_name do
          :nil -> "OvhClient"
          client_name -> client_name
        end
        {
          ":" <> app_name <> ", " <> Macro.camelize(app_name) <> "." <> client_name,
          String.upcase(other) <> "_" <> Morph.to_snake_caps(client_name) <>"_"
        }
    end
    {config_header, mod_client_name}
  end

  defp create_or_update_env_file(options) do
    env_path = ".env"
    File.touch!(env_path)
    existing = File.read!(env_path)
    {_config_header, mod_client_name} = config_names(options.application_name, options.client_name)
    new = existing <>
    ~s"""

    # updated on #{formatted_date()}
    export #{mod_client_name <> "APPLICATION_KEY"}=\"#{options.application_key}\"
    export #{mod_client_name <> "APPLICATION_SECRET"}="#{options.application_secret}\"
    export #{mod_client_name <> "CONSUMER_KEY"}="#{options.consumer_key}\"

    """
    {:ok, file} = File.open(env_path, [:write, :utf8])
    IO.binwrite(file, new)
    File.close(file)
    options
  end


  defp print_config(options) do
    Og.context(__ENV__, :debug)
    {config_header, mod_client_name} = config_names(options.application_name, options.client_name)

    ~s"""

    Add the following paragraph to the config.exs file(s):

    config #{config_header},
        ovh: [
          application_key: System.get_env(\"#{mod_client_name <> "APPLICATION_KEY"}\"),
          application_secret: System.get_env(\"#{mod_client_name <> "APPLICATION_SECRET"}\"),
          consumer_key: System.get_env(\"#{mod_client_name <> "CONSUMER_KEY"}\"),
          endpoint: \"#{options.endpoint}\",
          api_version: \"#{options.api_version}\"
        ]
    """
  end


  defp formatted_date() do
    {year, month, date} = :erlang.date()
    Integer.to_string(date) <> "." <>
    Integer.to_string(month) <> "." <>
    Integer.to_string(year)
  end


end