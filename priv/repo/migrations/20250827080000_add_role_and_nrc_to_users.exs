defmodule Bank.Repo.Migrations.AddRoleAndNrcToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string
      add :nrc, :string
    end

    create unique_index(:users, [:nrc])
  end
end
