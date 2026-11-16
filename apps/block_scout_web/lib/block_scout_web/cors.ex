defmodule BlockScoutWeb.CORS do
  @moduledoc """
  Runtime CORS origin resolution for CORSPlug.

  `CORS_ALLOWED_ORIGINS` is parsed in `config/runtime.exs`. When it is unset the
  plug keeps the historical wildcard origin. When it is a list of origins,
  CORSPlug echoes the matching `Origin` request header and sends
  `Access-Control-Allow-Credentials: true` (its default), which browsers require
  for credentialed account requests.
  """

  @wildcard "*"

  @doc """
  Allowed origins for CORSPlug.

  Returns `"*"` when no explicit origins are configured so existing wildcard
  behavior is preserved. Otherwise returns the configured list of origins.
  """
  @spec origin() :: String.t() | [String.t()]
  def origin do
    Application.get_env(:block_scout_web, :cors_allowed_origins, @wildcard)
  end
end
