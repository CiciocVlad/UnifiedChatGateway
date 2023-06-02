import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :live, LiveWeb.Endpoint,
  http: [port: 4010],
  url: [path: "/chat"],
  # start endpoint without mix command php.server
  # server: true,
  debug_errors: true,
  render_errors: [accepts: ~w(json)],
  code_reloader: true,
  check_origin: false,
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ],
  # configuration required for socket - longpoll: secrect key base and pubsub
  secret_key_base: "3fXws7MeTX6XkOYrBI4apLYW7avsgoyKmAjDwpYTFj07JatEmKPS6PCF4AYuqszq",
  socket_longpoll: [
    window_ms: 10_000,
    transport_log: false,
    crypto: [max_age: 1_209_600]
  ],
  live_view: [signing_salt: "FyWoxNB9hnS19QJj"]

config :live, :longpoll,
  window_ms: 60_000,
  crypto: [max_age: 1_209_600]

config :live,
  # 5 mins
  ws_timeout: 300_000,
  runtime_link_expiry: 1_440

config :live, images_path: "/images"
config :live, svg_path: "/svg"

config :chat,
  # seconds
  contact_proc_idle_timeout: 900,
  message_formats: [
    "email",
    "configuration",
    "text",
    "html",
    "form",
    "formResponse",
    "file",
    "image",
    "video"
  ],
  cirrus_base_urls: ["10.3.65.198:21000"],
  # miliseconds
  cirrus_ws_keepalive: 20000,
  rate_limit: 4,
  rate_limit_scale: 1_000,
  rate_limit_white_list: ["127.0.0.1"]

config :chat_db,
  pools: [
    {:config, [5, 'couchbase05.dev.premiercontactpoint.com:8091', 'config', 'pcp123', 'config']}
  ],
  bucket_config: [
    {"tenant", :config},
    {"cluster", :config},
    {"contactPoint", :config},
    {"defaultTimeZone", :config},
    {"form", :config},
    {"attachment", :config},
    {"chatConfiguration", :config}
  ]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :cors_plug,
  origin: ["*"]

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

config :lager,
  # What handlers to install with what arguments
  handlers: [
    lager_file_backend: [
      file: 'info.log',
      level: :debug,
      formatter: :lager_default_formatter,
      formatter_config: [
        :date,
        "|",
        :time,
        "|",
        :sev,
        "|",
        :pid,
        "|",
        {:tenant, [:tenant, "|"], [""]},
        {:mod, [:mod, "|"], [""]},
        :message,
        "\n"
      ],
      size: 0,
      date: []
    ]
  ],
  # Whether to write a crash log, and where. Undefined means no crash logger.
  crash_log: 'crash.log',
  # Maximum size in bytes of events in the crash log - defaults to 65536
  crash_log_msg_size: 65536,
  # Maximum size of the crash log in bytes, before its rotated, set
  # to 0 to disable rotation - default is 0
  crash_log_size: 0,
  # Whether to redirect error_logger messages into lager - defaults to true
  error_logger_redirect: false,
  # How many messages per second to allow from error_logger before we start dropping them
  error_logger_hwm: :undefined,
  # How big the gen_event mailbox can get before it is switched into sync mode
  async_threshold: 100

config :logger,
  backends: [LoggerLagerBackend],
  handle_otp_reports: true,
  level: :debug,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]
