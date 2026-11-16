defmodule BlockScoutWeb.CORSTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.CORS

  @frontend_origin "https://blockscan.marscredit.xyz"
  @stats_path "/api/v2/stats"

  setup do
    original = Application.get_env(:block_scout_web, :cors_allowed_origins)

    on_exit(fn ->
      Application.put_env(:block_scout_web, :cors_allowed_origins, original)
    end)

    :ok
  end

  describe "origin/0" do
    test "defaults to wildcard" do
      Application.put_env(:block_scout_web, :cors_allowed_origins, "*")
      assert CORS.origin() == "*"
    end

    test "returns configured origin list" do
      Application.put_env(:block_scout_web, :cors_allowed_origins, [@frontend_origin])
      assert CORS.origin() == [@frontend_origin]
    end
  end

  describe "ConfigHelper.parse_cors_allowed_origins_value/1" do
    test "unset and empty values keep the wildcard" do
      assert ConfigHelper.parse_cors_allowed_origins_value(nil) == "*"
      assert ConfigHelper.parse_cors_allowed_origins_value("") == "*"
    end

    test "parses a comma-separated list of full origins" do
      assert ConfigHelper.parse_cors_allowed_origins_value("https://blockscan.marscredit.xyz, http://localhost:3000") ==
               ["https://blockscan.marscredit.xyz", "http://localhost:3000"]
    end

    test "expands scheme-less hostnames to https and http origins" do
      assert ConfigHelper.parse_cors_allowed_origins_value("blockscan.marscredit.xyz") == [
               "https://blockscan.marscredit.xyz",
               "http://blockscan.marscredit.xyz"
             ]
    end

    test "trims trailing slashes" do
      assert ConfigHelper.parse_cors_allowed_origins_value("https://blockscan.marscredit.xyz/") == [
               "https://blockscan.marscredit.xyz"
             ]
    end
  end

  describe "CORS preflight" do
    test "allows updated-gas-oracle and recaptcha request headers", %{conn: conn} do
      conn = preflight(conn, @frontend_origin, "updated-gas-oracle,recaptcha-v3-token,recaptcha-v2-response")

      # CORSPlug answers preflight with 204 No Content
      assert conn.status == 204
      allow_headers = cors_header(conn, "access-control-allow-headers")
      assert allow_headers =~ "updated-gas-oracle"
      assert allow_headers =~ "recaptcha-v2-response"
      assert allow_headers =~ "recaptcha-v3-response"
      assert allow_headers =~ "recaptcha-v3-token"
      assert allow_headers =~ "recaptcha-bypass-token"
      assert allow_headers =~ "scoped-recaptcha-bypass-token"
    end

    test "keeps wildcard origin when CORS_ALLOWED_ORIGINS is unset", %{conn: conn} do
      Application.put_env(:block_scout_web, :cors_allowed_origins, "*")

      conn = preflight(conn, @frontend_origin, "updated-gas-oracle")

      assert cors_header(conn, "access-control-allow-origin") == "*"
    end

    test "echoes the matching request origin and allows credentials", %{conn: conn} do
      Application.put_env(:block_scout_web, :cors_allowed_origins, [@frontend_origin])

      conn = preflight(conn, @frontend_origin, "updated-gas-oracle")

      assert cors_header(conn, "access-control-allow-origin") == @frontend_origin
      assert cors_header(conn, "access-control-allow-credentials") == "true"
    end

    test "does not allow a non-matching origin when a list is configured", %{conn: conn} do
      Application.put_env(:block_scout_web, :cors_allowed_origins, [@frontend_origin])

      conn = preflight(conn, "https://evil.example", "updated-gas-oracle")

      assert get_resp_header(conn, "access-control-allow-origin") == []
    end

    test "matches a scheme-less hostname after expansion", %{conn: conn} do
      Application.put_env(
        :block_scout_web,
        :cors_allowed_origins,
        ConfigHelper.parse_cors_allowed_origins_value("blockscan.marscredit.xyz")
      )

      conn = preflight(conn, @frontend_origin, "updated-gas-oracle")

      assert cors_header(conn, "access-control-allow-origin") == @frontend_origin
      assert cors_header(conn, "access-control-allow-credentials") == "true"
    end
  end

  defp preflight(conn, origin, request_headers) do
    conn
    |> put_req_header("origin", origin)
    |> put_req_header("access-control-request-method", "GET")
    |> put_req_header("access-control-request-headers", request_headers)
    |> options(@stats_path)
  end

  defp cors_header(conn, name) do
    conn
    |> get_resp_header(name)
    |> List.first()
  end
end
