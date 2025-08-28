defmodule Bank.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :number, :string
    field :balance, :decimal, default: Decimal.new("0")
    field :type, :string, default: "savings"
    belongs_to :user, Bank.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating an account.
  """
  def changeset(account, attrs) do
    IO.inspect(attrs, label: "Account attrs")
    
    # Convert balance string to Decimal if present
    attrs = case attrs do
      %{"balance" => balance} when is_binary(balance) ->
        case Decimal.parse(balance) do
          {decimal, _} -> Map.put(attrs, "balance", decimal)
          :error -> attrs
        end
      _ -> attrs
    end
    
    account
    |> cast(attrs, [:number, :balance, :type, :user_id])
    |> validate_required([:number, :type, :user_id])
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> validate_length(:number, min: 10, max: 10)
    |> validate_format(:number, ~r/^\d{10}$/, message: "must be exactly 10 digits")
    |> unique_constraint(:number)
    |> foreign_key_constraint(:user_id)
  end

  def generate_account_number do
    # Generate a random 10-digit number
    random = :rand.uniform(9_999_999_999)
    String.pad_leading(Integer.to_string(random), 10, "0")
  end
end
