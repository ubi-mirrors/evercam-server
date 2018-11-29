defmodule EvercamMedia.Repo.Migrations.AddVideoFieldInTimelapses do
  use Ecto.Migration

  def change do
    alter table(:timelapses) do
      add :video, :boolean, default: true
    end
  end
end
