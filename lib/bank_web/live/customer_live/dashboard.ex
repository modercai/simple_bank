defmodule BankWeb.CustomerLive.Dashboard do
  use BankWeb, :live_view

  import Ecto.Query, warn: false
  alias Bank.Transactions

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    accounts = get_user_accounts(user.id)
    recent_transactions = get_recent_transactions(user.id)
    total_balance = calculate_total_balance(accounts)

    {:ok,
     assign(socket,
       accounts: accounts,
       recent_transactions: recent_transactions,
       total_balance: total_balance
     )}
  end
  
  defp get_user_accounts(user_id) do
    Bank.Repo.all(
      from a in Bank.Accounts.Account,
      where: a.user_id == ^user_id,
      preload: [:user]
    )
  end

  defp get_recent_transactions(user_id) do
    Transactions.list_transactions_by_user(user_id)
    |> Enum.take(5)
  end

  defp calculate_total_balance(accounts) do
    accounts
    |> Enum.reduce(Decimal.new("0"), fn account, acc ->
      Decimal.add(acc, account.balance)
    end)
  end
end
