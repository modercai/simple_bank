defmodule BankWeb.CustomerLive.Transactions do
  use BankWeb, :live_view

  alias Bank.Transactions
  alias Bank.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    accounts = get_user_accounts(user.id)
    transactions = Transactions.list_transactions_by_user(user.id)
    
    {:ok,
     assign(socket,
       accounts: accounts,
       transactions: transactions,
       all_transactions: transactions,
       selected_account_id: nil,
       filter_type: "all"
     )}
  end

  def handle_event("filter_by_account", %{"account_id" => account_id}, socket) do
    filtered_transactions = if account_id == "" do
      socket.assigns.all_transactions
    else
      account_id_int = String.to_integer(account_id)
      Transactions.list_transactions_by_account(account_id_int)
    end

    {:noreply,
     assign(socket,
       transactions: filtered_transactions,
       selected_account_id: if(account_id == "", do: nil, else: account_id)
     )}
  end

  def handle_event("filter_by_type", %{"type" => type}, socket) do
    base_transactions = if socket.assigns.selected_account_id do
      account_id = String.to_integer(socket.assigns.selected_account_id)
      Transactions.list_transactions_by_account(account_id)
    else
      socket.assigns.all_transactions
    end

    filtered_transactions = if type == "all" do
      base_transactions
    else
      Enum.filter(base_transactions, &(&1.type == type))
    end

    {:noreply,
     assign(socket,
       transactions: filtered_transactions,
       filter_type: type
     )}
  end

  defp get_user_accounts(user_id) do
    import Ecto.Query
    Bank.Repo.all(
      from a in Bank.Accounts.Account,
      where: a.user_id == ^user_id,
      preload: [:user]
    )
  end

  def transaction_type_display(type) do
    case type do
      "withdrawal" -> "Withdrawal"
      "transfer_in" -> "Transfer Received"
      "transfer_out" -> "Transfer Sent"
      "deposit" -> "Deposit"
      _ -> String.replace(type, "_", " ") |> String.capitalize()
    end
  end

  def transaction_amount_class(type) do
    case type do
      type when type in ["withdrawal", "transfer_out"] -> "text-red-600"
      _ -> "text-green-600"
    end
  end

  def transaction_amount_prefix(type) do
    case type do
      type when type in ["withdrawal", "transfer_out"] -> "-"
      _ -> "+"
    end
  end

  def format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
