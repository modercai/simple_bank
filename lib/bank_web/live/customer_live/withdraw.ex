defmodule BankWeb.CustomerLive.Withdraw do
  use BankWeb, :live_view

  alias Bank.Accounts
  alias Bank.Transactions

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    accounts = get_user_accounts(user.id)
    
    form = to_form(%{"account_id" => "", "amount" => ""})

    {:ok,
     assign(socket,
       accounts: accounts,
       form: form,
       selected_account: nil
     )}
  end

  def handle_event("select_account", %{"account_id" => account_id}, socket) do
    selected_account = if account_id == "" do
      nil
    else
      Accounts.get_account!(account_id)
    end

    form = to_form(%{"account_id" => account_id, "amount" => ""})

    {:noreply,
     assign(socket,
       selected_account: selected_account,
       form: form
     )}
  end

  def handle_event("withdraw", %{"account_id" => account_id, "amount" => amount}, socket) do
    user_scope = socket.assigns.current_scope
    account = Accounts.get_account!(account_id)

    case Decimal.parse(amount) do
      {parsed_amount, _} when not is_nil(parsed_amount) ->
        if Decimal.compare(parsed_amount, Decimal.new("0")) == :gt do
          case Transactions.withdraw_funds(account, parsed_amount, user_scope) do
            {:ok, {_updated_account, _transaction}} ->
              {:noreply,
               socket
               |> put_flash(:info, "Withdrawal successful! ZMW #{amount} has been withdrawn from your account.")
               |> redirect(to: ~p"/dashboard")}

            {:error, :insufficient_funds} ->
              {:noreply,
               socket
               |> put_flash(:error, "Insufficient funds. Your account balance is ZMW #{account.balance}.")}

            {:error, changeset} ->
              {:noreply,
               socket
               |> put_flash(:error, "Withdrawal failed: #{inspect(changeset.errors)}")}
          end
        else
          {:noreply,
           socket
           |> put_flash(:error, "Amount must be greater than zero.")}
        end

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Please enter a valid amount.")}
    end
  end

  defp get_user_accounts(user_id) do
    import Ecto.Query
    Bank.Repo.all(
      from a in Bank.Accounts.Account,
      where: a.user_id == ^user_id,
      preload: [:user]
    )
  end

  def quick_amounts(balance) do
    amounts = [50, 100, 200, 500]
    amounts
    |> Enum.filter(fn amount -> 
      Decimal.compare(Decimal.new(amount), balance) != :gt
    end)
    |> Enum.take(3)
  end
end
