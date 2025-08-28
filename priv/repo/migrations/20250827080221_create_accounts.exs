defmodule Bank.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :account_number, :string
      add :balance, :decimal
      add :status, :string
      add :user_id, references(:users, on_delete: :nothing)


      timestamps(type: :utc_datetime)
    end

    create index(:accounts, [:user_id])

  end
end
