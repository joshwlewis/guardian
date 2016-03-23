defmodule Guardian.Plug.LoadResource do
  @moduledoc """
  Fetches the resource specified in a set of claims.

  The `Guardian.serializer/0` is used
  once the subject is extracted from the token.

  The resource becomes available at `Guardian.Plug.current_resource(conn)`
  if successful.

  If there is no valid JWT in the request so far (Guardian.Plug.VerifySession /
  Guardian.Plug.VerifyHeader) did not find a valid token
  then nothing will occur, and the Guardian.Plug.current_resource/1 will be
  nil.

  A module may be specified as the `:handler` option to catch any errors
  arising from resource deserialization. The specified  module will need to
  implement `invalid_resource/2`. If no handler is specified,
  `Guardian.Plug.current_resource/1` will be nil on any deserialization error.
  """
  import Plug.Conn

  @doc false
  def init(opts \\ %{}) do
    Enum.into(opts, %{})
    case opts.handler do
      nil -> opts
      mod -> Enum.put(:handler, {mod, :invalid_resource})
    end
  end

  @doc false
  def call(conn, opts) do
    key = Map.get(opts, :key, :default)

    case Guardian.Plug.current_resource(conn, key) do
      {:ok, _} -> conn
      {:error, _} -> conn
      _ ->
        case Guardian.Plug.claims(conn, key) do
          {:ok, claims} ->
            result = Guardian.serializer.from_token(Map.get(claims, "sub"))
            set_current_resource_from_serializer(conn, key, result, opts)
          _ ->
            Guardian.Plug.set_current_resource(conn, nil, key)
        end
    end
  end

  defp set_current_resource_from_serializer(conn, key, {:ok, resource}, _opts) do
    Guardian.Plug.set_current_resource(conn, resource, key)
  end

  defp set_current_resource_from_serializer(conn, key, reason, opts) do
    Guardian.Plug.set_current_resource(conn, nil, key)
    |> handle_error(reason, opts)
  end

  def handle_error(conn, reason, opts) do
    case Map.get(opts, :handler) do
      {mod, meth} ->
        connection = conn |> assign(:guardian_failure, reason) |> halt
        options = Map.merge(connection.params, %{reason: reason})
        apply(mod, meth, [connection, options])
      _ -> conn
    end
  end
end
