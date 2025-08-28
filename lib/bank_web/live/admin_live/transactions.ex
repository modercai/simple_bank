defmodule BankWeb.AdminLive.Transactions do
  use BankWeb, :live_view

  alias Bank.Transactions
  alias Bank.Accounts


  def mount(_params, _session, socket) do
    {:ok,
      assign(socket,
        users: Accounts.list_customers(),
        transactions: Transactions.list_transactions()
      )
    }
  end

  def handle_event("filter", %{"user_id" => user_id}, socket) do
    transactions =
      if user_id == "" do
        Transactions.list_transactions()
      else
        Transactions.list_transactions_by_user(user_id)
      end

    {:noreply, assign(socket, transactions: transactions)}
  end
end
