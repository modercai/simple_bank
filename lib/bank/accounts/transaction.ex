defmodule Bank.Accounts.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :type, :string
    field :amount, :decimal
    field :account_id, :id
    field :to_account_id, :id
    field :user_id, :id
    field :momo_reference_id, :string
    field :momo_status, :string, default: "pending"
    field :phone_number, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(
          {map(),
           %{
             optional(atom()) =>
               atom()
               | {:array | :assoc | :embed | :in | :map | :parameterized | :supertype | :try,
                  any()}
           }}
          | %{
              :__struct__ => atom() | %{:__changeset__ => any(), optional(any()) => any()},
              optional(atom()) => any()
            },
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()},
          any()
        ) :: Ecto.Changeset.t()
  @doc false

  def changeset(transaction, attrs, user_scope) do
    transaction
    |> cast(attrs, [:type, :amount, :account_id, :to_account_id, :momo_reference_id, :momo_status, :phone_number])
    |> validate_required([:type, :amount])
    |> put_change(:user_id, user_scope.user.id)
  end
end
