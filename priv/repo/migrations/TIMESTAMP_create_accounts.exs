defmodule Bank.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :number, :string, null: false
      add :balance, :decimal, null: false, default: 0
      add :type, :string, null: false, default: "savings"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:accounts, [:number])
    create index(:accounts, [:user_id])
  end
end
