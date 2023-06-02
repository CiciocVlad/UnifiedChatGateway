import Config
import_config "dev.exs"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :live, LiveWeb.Endpoint, http: [port: 4022]

config :chat,
  contact_proc_idle_timeout: 2,
  cirrus_api_base_url: "http://test/cirrusapi",
  rate_limit: 1,
  rate_limit_scale: 1_000,
  rate_limit_white_list: ["127.0.0.1"]

# Print only warnings and errors during test
config :logger,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  backends: [:console]

config :logger, :console,
  level: :debug,
  format: "$date|$time|[$level]$levelpad|$metadata|$message\n",
  metadata: [:module, :line, :pid]
