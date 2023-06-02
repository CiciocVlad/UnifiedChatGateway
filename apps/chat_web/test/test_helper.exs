defmodule ChatWeb.TestHelper do
  def meck(modules) do
    meck_new(modules, [:no_link, :non_strict])
    |> meck_validate()
  end

  def meck_new(modules, opts) do
    :ok = :meck.new(modules, opts ++ [:no_link])
    modules
  end

  def meck_validate(modules) do
    ExUnit.Callbacks.on_exit(fn -> do_meck_validate(modules) end)
  end

  @syntax_colors [
    reset: :reset,
    nil: :magenta,
    boolean: :magenta,
    atom: :cyan,
    number: :default_color,
    tuple: :default_color,
    list: :default_color,
    binary: :default_color,
    string: :green,
    map: :default_color,
    pid: :magenta,
    stack: :light_blue
  ]

  def meck_modules() do
    Process.registered()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.filter(&String.ends_with?(&1, "_meck"))
    |> Enum.map(&String.to_atom(binary_part(&1, 0, byte_size(&1) - 5)))
  end

  defp format_call(mod, fun, args, result, pid, callstack \\ nil) do
    import Inspect.Algebra

    opts = %Inspect.Opts{limit: :infinity, syntax_colors: @syntax_colors}
    render_arg = fn arg, opts -> group(to_doc(arg, opts)) end

    args = container_doc("(", args, ")", opts, render_arg, [:flex])
    result = to_doc(result, opts)

    pid =
      case pid do
        nil -> empty()
        _ -> color(to_doc(pid, opts), :pid, opts) |> concat(": ")
      end

    callstack =
      case callstack do
        nil ->
          empty()

        _ ->
          concat(line(), Exception.format_stacktrace(callstack) |> color(:stack, opts))
      end

    [line(), pid, inspect(mod), ".", Atom.to_string(fun)]
    |> concat()
    |> group()
    |> concat(group(args))
    |> concat(group(glue(" ->", group(result))) |> nest(2, :break))
    |> group()
    |> concat(callstack)
  end

  def meck_history() do
    meck_history(meck_modules())
  end

  def meck_history(modules) do
    import Inspect.Algebra

    opts = %Inspect.Opts{limit: :infinity, syntax_colors: @syntax_colors}

    history =
      for mod <- modules do
        history =
          for {pid, {mod, fun, args}, result} <- :meck.history(mod) do
            format_call(mod, fun, args, result, pid)
          end

        [line(), color(inspect(mod), :atom, opts), ":", nest(concat(history), 2)]
        |> concat()
        |> group()
      end

    [
      line(),
      color("History for meck:", :bright, opts),
      nest(concat(history), 2)
    ]
    |> concat()
    |> format(120)
    |> IO.puts()
  catch
    c, e ->
      IO.puts([IO.ANSI.red(), Exception.format(c, e), IO.ANSI.reset()])
  end

  defp do_meck_validate(modules) when is_list(modules) do
    case :meck.validate(modules) do
      false ->
        meck_history(modules)

        meck_unload_and_validate(modules)
        raise "meck validation failed"

      true ->
        # meck_history(modules)

        meck_unload_and_validate(modules)
    end
  end

  defp meck_unload_and_validate(modules) do
    case :meck.unload() -- modules do
      [] ->
        true

      invalid ->
        raise "couldn't validate modules: #{inspect(invalid)}"
    end
  end

  def ensure_started(apps) do
    started =
      apps
      |> Enum.flat_map(fn app ->
        {:ok, started} = Application.ensure_all_started(app)
        started
      end)

    ExUnit.Callbacks.on_exit(fn ->
      started
      |> Enum.reverse()
      |> Enum.each(&(:ok = Application.stop(&1)))
    end)
  end
end

ExUnit.configure(formatters: [ExUnit.CLIFormatter])
ExUnit.start()
