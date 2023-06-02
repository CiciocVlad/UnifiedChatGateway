import Config

config :lager,
  # What handlers to install with what arguments
  handlers: [
    lager_file_backend: [
      file: 'info.log',
      level: :info,
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
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]
