defmodule SnapmailLogs do
  use EvercamMediaWeb, :model
  alias EvercamMedia.SnapshotRepo
  alias EvercamMedia.Util
  require Logger

  @required_fields ~w(body)
  @optional_fields ~w(subject recipients image_timestamp)

  schema "snapmail_logs" do
    field :recipients, :string
    field :subject, :string
    field :body, :string
    field :image_timestamp, :string

    timestamps(type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def save_snapmail(recipients, subject, body, image_timestamp) do
    SnapmailLogs.changeset(%SnapmailLogs{}, %{
      recipients: recipients,
      subject: subject,
      body: body,
      image_timestamp: image_timestamp
    })
    |> SnapshotRepo.insert
    |> handle_save_results
  end

  defp handle_save_results({:ok, _}), do: :noop
  defp handle_save_results({:error, changeset}), do: Logger.info Util.parse_changeset(changeset)

  def required_fields do
    @required_fields |> Enum.map(fn(field) -> String.to_atom(field) end)
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(required_fields())
  end
end
