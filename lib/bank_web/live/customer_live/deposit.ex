
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

   
    current_params = socket.assigns.form.params
    updated_params = Map.put(current_params, "account_id", account_id)
    form = to_form(updated_params)

    {:noreply,
     assign(socket,
       selected_account: selected_account,
       form: form
     )}
  end

  def handle_event("payment_method_change", %{"payment_method" => method}, socket) do

    current_params = socket.assigns.form.params
    updated_params = 
      current_params
      |> Map.put("payment_method", method)
      |> then(fn params ->
        if method != "momo" do
          Map.put(params, "phone_number", "")
        else
          params
        end
      end)
    
    form = to_form(updated_params)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("form_change", params, socket) do
    form = to_form(params)
    {:noreply, assign(socket, form: form)}
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
           |> put_flash(:info, "Mobile Money payment request sent successfully! You'll receive a prompt on #{phone_number}. Please complete the payment to finalize your deposit.")
           |> redirect(to: ~p"/dashboard")}

        {:error, reason} when is_binary(reason) ->
          {:noreply,
           socket
           |> put_flash(:error, "Mobile Money payment failed: #{reason}")}

        {:error, changeset} ->
          error_messages = 
            changeset.errors
            |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
            |> Enum.join(", ")
          
          {:noreply,
           socket
           |> put_flash(:error, "Deposit failed: #{error_messages}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please enter a valid Zambian phone number (e.g., 0977123456 or 260977123456).")}
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

  defp valid_phone_number?(phone_number) do # TODO : i have two of these functions now in the system, what file should i put it in?
    cleaned = String.replace(phone_number, ~r/[\s\-\+]/, "")
    String.match?(cleaned, ~r/^(09\d{8}|260[79]\d{8})$/)
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
