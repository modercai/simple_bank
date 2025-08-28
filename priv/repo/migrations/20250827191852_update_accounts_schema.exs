defmodule Bank.Repo.Migrations.UpdateAccountsSchema do
  use Ecto.Migration

  def change do
    # Rename account_number to number
    rename table(:accounts), :account_number, to: :number
    
    # Add type column and modify constraints
    alter table(:accounts) do
      add :type, :string, default: "savings"
      modify :number, :string, null: false
      modify :balance, :decimal, null: false, default: 0
      remove :status
    end
    
    # Add unique index on number
    create unique_index(:accounts, [:number])
  end
end
