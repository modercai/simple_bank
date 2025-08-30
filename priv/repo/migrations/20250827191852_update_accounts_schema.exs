defmodule Bank.Repo.Migrations.UpdateAccountsSchema do
  use Ecto.Migration

  def change do

    rename table(:accounts), :account_number, to: :number
    
    alter table(:accounts) do
      add :type, :string, default: "savings"
      modify :number, :string, null: false
      modify :balance, :decimal, null: false, default: 0
      remove :status
    end

    create unique_index(:accounts, [:number])
  end
end
