defmodule EvercamMedia.Janitor do
  @moduledoc """
    This is a Janitor for evercam_media, the purpose of this Module is to do things,
    which were stopped due to hot upgrade. We encountered Porcelain app to be the one
    to stop on hot upgrade. We are using code_change/3 callback module to handle this issue.
  """

  use GenServer
  require Logger
  @vsn DateTime.to_unix(DateTime.utc_now())

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(_args) do
    {:ok, 1}
  end

  def code_change(_old_vsn, state, _extra) do
    Logger.info "Re-init Porcelain"
    ensure_porcelain_is_init()
    {:ok, state}
  end

  defp ensure_porcelain_is_init do
    Porcelain.Init.init()
  end
end
