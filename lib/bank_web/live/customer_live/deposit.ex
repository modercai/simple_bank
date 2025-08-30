
defmodule BankWeb.CustomerLive.Deposit do
  use BankWeb, :live_view

  alias Bank.Accounts
  alias Bank.Transactions

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    accounts = get_user_accounts(user.id)

    form = to_form(%{"account_id" => "", "amount" => "", "payment_method" => "instant", "phone_number" => ""})

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

    form = to_form(%{"account_id" => account_id, "amount" => "", "payment_method" => "instant", "phone_number" => ""})

    {:noreply,
     assign(socket,
       selected_account: selected_account,
       form: form
     )}
  end

  def handle_event("deposit", params, socket) do
    %{
      "account_id" => account_id,
      "amount" => amount,
      "payment_method" => payment_method,
      "phone_number" => phone_number
    } = params

    user_scope = socket.assigns.current_scope
    account = Accounts.get_account!(account_id)

    case Decimal.parse(amount) do
      {parsed_amount, _} when not is_nil(parsed_amount) ->
        if Decimal.compare(parsed_amount, Decimal.new("0")) == :gt do
          handle_deposit_by_method(socket, account, parsed_amount, payment_method, phone_number, user_scope)
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

  defp handle_deposit_by_method(socket, account, amount, "momo", phone_number, user_scope) do
    if valid_phone_number?(phone_number) do
      case Transactions.deposit_funds_with_momo(account, amount, phone_number, user_scope) do
        {:ok, {:pending, _transaction}} ->
          {:noreply,
           socket
           |> put_flash(:info, "Mobile Money payment request sent. You'll receive a prompt on #{phone_number}. Please complete the payment.")
           |> redirect(to: ~p"/dashboard")}

        {:error, reason} when is_binary(reason) ->
          {:noreply,
           socket
           |> put_flash(:error, "Mobile Money payment failed: #{reason}")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Deposit failed: #{inspect(changeset.errors)}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please enter a valid phone number.")}
    end
  end

  defp handle_deposit_by_method(socket, account, amount, "instant", _phone_number, user_scope) do
    case Transactions.deposit_funds(account, amount, user_scope) do
      {:ok, {_updated_account, _transaction}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deposit successful! ZMW #{amount} has been added to your account.")
         |> redirect(to: ~p"/dashboard")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Deposit failed: #{inspect(changeset.errors)}")}
    end
  end

  defp valid_phone_number?(phone_number) do

    String.match?(phone_number, ~r/^(09|26)\d{8}$/)
  end

  defp get_user_accounts(user_id) do
    import Ecto.Query
    Bank.Repo.all(
      from a in Bank.Accounts.Account,
      where: a.user_id == ^user_id,
      preload: [:user]
    )
  end

  def quick_amounts do
    [50, 100, 200, 500, 1000, 2000]
  end
end
