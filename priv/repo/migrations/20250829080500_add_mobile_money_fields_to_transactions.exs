defmodule Bank.Repo.Migrations.AddMobileMoneyFieldsToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :momo_reference_id, :string
      add :momo_status, :string, default: "pending"
      add :phone_number, :string
    end

    create index(:transactions, [:momo_reference_id])
  end
end