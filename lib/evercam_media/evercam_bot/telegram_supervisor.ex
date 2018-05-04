defmodule EvercamMedia.EvercamBot.TelegramSupervisor do
  @moduledoc """
  Provides function to manage Telegram_bot workers
  """

  use Supervisor
  require Logger
  @bot_name Application.get_env(:evercam_media, :bot_name)

  def start_link() do
    Supervisor.start_link __MODULE__, :ok, name: __MODULE__
  end

  def init(:ok) do
    case Application.get_env(:evercam_media, :start_evercam_bot) do
      true ->
        Task.start_link(&start_matcher/0)
        children = [
          worker(EvercamMedia.EvercamBot.Poller, [], restart: :permanent),
          worker(EvercamMedia.EvercamBot.Matcher, [], restart: :permanent)
        ]
        supervise(children, strategy: :one_for_one, max_restarts: 1_000_000)
      false ->
        children = [
          worker(EvercamMedia.EvercamBot.Matcher, [], restart: :permanent)
        ]
        supervise(children, strategy: :one_for_one, max_restarts: 1_000_000)
    end
  end

  @doc """
  Start Telegram_bot worker
  """
  def start_matcher() do
    unless String.valid?(@bot_name) do
      IO.warn """

      Env not found Application.get_env(:app, :bot_name)
      This will give issues when generating commands
      """
    end

    if @bot_name == "testevercam_bot" do
      IO.warn "An empty bot_name env will make '/anycommand@' valid"
      Supervisor.start_child __MODULE__, []
    end

  end
end
