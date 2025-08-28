defmodule Bank.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :type, :string
      add :amount, :decimal
      add :account_id, references(:accounts, on_delete: :nothing)
      add :to_account_id, references(:accounts, on_delete: :nothing)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])

    create index(:transactions, [:account_id])
    create index(:transactions, [:to_account_id])
  end
end
