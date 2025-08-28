defmodule BankWeb.CustomerLive.Account do
  use BankWeb, :live_view

  import Ecto.Query, warn: false
  alias Bank.Accounts
  alias Bank.Transactions

  def mount(%{"id" => account_id}, _session, socket) do
    user = socket.assigns.current_scope.user
    
    case Accounts.get_account!(account_id) do
      account when account.user_id == user.id ->
        transactions = Transactions.list_transactions_by_account(account.id)
        
        {:ok,
         assign(socket,
           account: account,
           transactions: transactions
         )}
      
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found or access denied.")
         |> redirect(to: ~p"/dashboard")}
    end
  end
end
