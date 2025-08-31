defmodule Bank.Transactions do
  @moduledoc """
  The Transactions context.
  """

  import Ecto.Query, warn: false
  alias Bank.Repo
  alias Bank.Accounts.Transaction
  alias Bank.Accounts
  alias Bank.MtnMomo
  alias Bank.Repo
  alias Bank.Accounts.Transaction

  @doc """
  Returns the list of transactions with pagination and filtering.

  ## Examples

      iex> list_transactions_paginated(%{page: 1, per_page: 10})
      {[%Transaction{}, ...], %{total_count: 100, total_pages: 10, current_page: 1}}

  """
  def list_transactions_paginated(opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 10)
    user_id = Map.get(opts, :user_id)
    date_from = Map.get(opts, :date_from)
    date_to = Map.get(opts, :date_to)
    transaction_type = Map.get(opts, :type)
    
    query = Transaction
    |> order_by(desc: :inserted_at)
    
    # Apply filters
    query = if user_id do
      where(query, [t], t.user_id == ^user_id)
    else
      query
    end
    
    query = if date_from do
      where(query, [t], t.inserted_at >= ^date_from)
    else
      query
    end
    
    query = if date_to do
      # Add 1 day to include the entire end date
      end_date = Date.add(date_to, 1) |> DateTime.new!(~T[00:00:00])
      where(query, [t], t.inserted_at < ^end_date)
    else
      query
    end
    
    query = if transaction_type && transaction_type != "all" do
      where(query, [t], t.type == ^transaction_type)
    else
      query
    end
    
    # Get total count
    total_count = Repo.aggregate(query, :count)
    total_pages = ceil(total_count / per_page)
    
    # Get paginated results
    offset = (page - 1) * per_page
    transactions = query
    |> limit(^per_page)
    |> offset(^offset)
    |> preload([:user])
    |> Repo.all()
    
    pagination_info = %{
      total_count: total_count,
      total_pages: total_pages,
      current_page: page,
      per_page: per_page,
      has_prev: page > 1,
      has_next: page < total_pages
    }
    
    {transactions, pagination_info}
  end

  @doc """
  Returns the list of transactions for a specific user.

  ## Examples

      iex> list_transactions_by_user(user_id)
      [%Transaction{}, ...]

  """
  def list_transactions_by_user(user_id) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of transactions for a specific account.

  ## Examples

      iex> list_transactions_by_account(account_id)
      [%Transaction{}, ...]

  """
  def list_transactions_by_account(account_id) do
    Transaction
    |> where([t], t.account_id == ^account_id or t.to_account_id == ^account_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.

  ## Examples

      iex> get_transaction!(123)
      %Transaction{}

      iex> get_transaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transaction!(id), do: Repo.get!(Transaction, id)

  @doc """
  Creates a transaction.

  ## Examples

      iex> create_transaction(%{field: value})
      {:ok, %Transaction{}}

      iex> create_transaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_transaction(attrs, user_scope) do
    %Transaction{}
    |> Transaction.changeset(attrs, user_scope)
    |> Repo.insert()
  end

  @doc """
  Processes a withdrawal from an account.
  """
  def withdraw_funds(account, amount, user_scope) do
    Repo.transaction(fn ->
      # Check if account has sufficient balance
      if Decimal.compare(account.balance, amount) == :lt do
        Repo.rollback(:insufficient_funds)
      else
        # Update account balance
        new_balance = Decimal.sub(account.balance, amount)
        case Accounts.change_account(account, %{"balance" => new_balance}) |> Repo.update() do
          {:ok, updated_account} ->
            # Create transaction record
            transaction_attrs = %{
              "type" => "withdrawal",
              "amount" => amount,
              "account_id" => account.id,
              "inserted_at" => DateTime.utc_now()
            }
            case create_transaction(transaction_attrs, user_scope) do
              {:ok, transaction} -> {updated_account, transaction}
              {:error, changeset} -> Repo.rollback(changeset)
            end
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end
    end)
  end

  @doc """
  Processes a regular deposit to an account.
  """
  def deposit_funds(account, amount, user_scope) do
    Repo.transaction(fn ->
      # Update account balance
      new_balance = Decimal.add(account.balance, amount)
      case Accounts.change_account(account, %{"balance" => new_balance}) |> Repo.update() do
        {:ok, updated_account} ->
          # Create transaction record
          transaction_attrs = %{
            "type" => "deposit",
            "amount" => amount,
            "account_id" => account.id,
            "inserted_at" => DateTime.utc_now()
          }
          case create_transaction(transaction_attrs, user_scope) do
            {:ok, transaction} -> {updated_account, transaction}
            {:error, changeset} -> Repo.rollback(changeset)
          end
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def deposit_funds_with_momo(account, amount, phone_number, user_scope) do
    case MtnMomo.request_to_pay(amount, phone_number) do
      {:ok, %{reference_id: reference_id}} ->
        # Create pending transaction !
        transaction_attrs = %{
          account_id: account.id,
          amount: amount,
          type: "deposit",
          momo_reference_id: reference_id,
          momo_status: "pending",
          phone_number: phone_number
        }

        %Transaction{}
        |> Transaction.changeset(transaction_attrs, user_scope)
        |> Repo.insert()
        |> case do
          {:ok, transaction} ->
              
            {:ok, {:pending, transaction}}

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, reason} ->
        {:error, reason}
    end
end

  @doc """
  Processes a transfer between two accounts.
  """
  def transfer_funds(from_account, to_account, amount, user_scope) do
    Repo.transaction(fn ->
      # Check if from_account has sufficient balance
      if Decimal.compare(from_account.balance, amount) == :lt do
        Repo.rollback(:insufficient_funds)
      else
        # Update from_account balance (subtract)
        new_from_balance = Decimal.sub(from_account.balance, amount)
        case Accounts.change_account(from_account, %{"balance" => new_from_balance}) |> Repo.update() do
          {:ok, updated_from_account} ->
            # Update to_account balance (add)
            new_to_balance = Decimal.add(to_account.balance, amount)
            case Accounts.change_account(to_account, %{"balance" => new_to_balance}) |> Repo.update() do
              {:ok, updated_to_account} ->
                # Create withdrawal transaction
                withdrawal_attrs = %{
                  "type" => "transfer_out",
                  "amount" => amount,
                  "account_id" => from_account.id,
                  "to_account_id" => to_account.id,
                  "inserted_at" => DateTime.utc_now()
                }
                case create_transaction(withdrawal_attrs, user_scope) do
                  {:ok, _withdrawal_transaction} ->
                    # Create deposit transaction
                    deposit_attrs = %{
                      "type" => "transfer_in",
                      "amount" => amount,
                      "account_id" => to_account.id,
                      "to_account_id" => from_account.id,
                      "inserted_at" => DateTime.utc_now()
                    }
                    case create_transaction(deposit_attrs, user_scope) do
                      {:ok, deposit_transaction} ->
                        {updated_from_account, updated_to_account, deposit_transaction}
                      {:error, changeset} -> Repo.rollback(changeset)
                    end
                  {:error, changeset} -> Repo.rollback(changeset)
                end
              {:error, changeset} -> Repo.rollback(changeset)
            end
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end
    end)
  end
end
