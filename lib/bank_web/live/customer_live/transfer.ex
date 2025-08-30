defmodule BankWeb.CustomerLive.Transfer do
  use BankWeb, :live_view

  alias Bank.Accounts
  alias Bank.Transactions

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    accounts = get_user_accounts(user.id)
    
    form = to_form(%{
      "from_account_id" => "",
      "to_account_number" => "",
      "amount" => "",
      "description" => ""
    })

    {:ok,
     assign(socket,
       accounts: accounts,
       form: form,
       selected_from_account: nil,
       recipient_account: nil,
       step: 1
     )}
  end

  def handle_event("select_from_account", %{"account_id" => account_id}, socket) do
    selected_account = if account_id == "" do
      nil
    else
      Accounts.get_account!(account_id)
    end

    form = to_form(%{
      "from_account_id" => account_id,
      "to_account_number" => "",
      "amount" => "",
      "description" => ""
    })

    {:noreply,
     assign(socket,
       selected_from_account: selected_account,
       form: form,
       step: if(selected_account, do: 2, else: 1)
     )}
  end

  def handle_event("lookup_recipient", params, socket) do
    account_number = case params do
      %{"to_account_number" => number} -> number
      %{"value" => number} -> number
      %{"_target" => ["to_account_number"], "to_account_number" => number} -> number
      _ -> ""
    end
    
    case String.trim(account_number) do
      "" ->
        {:noreply,
         assign(socket,
           recipient_account: nil,
           step: 2
         )}
      
      number when byte_size(number) == 10 ->
        case Bank.Repo.get_by(Bank.Accounts.Account, number: number) |> Bank.Repo.preload(:user) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Account number not found.")
             |> assign(recipient_account: nil, step: 2)}
          
          account ->
            cond do
              account.user_id == socket.assigns.current_scope.user.id ->
                {:noreply,
                 socket
                 |> put_flash(:error, "You cannot transfer to your own account.")
                 |> assign(recipient_account: nil, step: 2)}
              
              account.user.status == "blocked" ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Cannot transfer to blocked user account.")
                 |> assign(recipient_account: nil, step: 2)}
              
              true ->
                {:noreply,
                 assign(socket,
                   recipient_account: account,
                   step: 3
                 )}
            end
        end
      
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Account number must be exactly 10 digits.")
         |> assign(recipient_account: nil, step: 2)}
    end
  end

  def handle_event("transfer", params, socket) do
    %{
      "from_account_id" => from_account_id,
      "amount" => amount
    } = params

    user_scope = socket.assigns.current_scope
    from_account = Accounts.get_account!(from_account_id)
    to_account = socket.assigns.recipient_account

    # Additional validation to ensure recipient is still not blocked
    if to_account && to_account.user.status == "blocked" do
      {:noreply,
       socket
       |> put_flash(:error, "Cannot transfer to blocked user account.")
       |> assign(step: 2, recipient_account: nil)}
    else
      case Decimal.parse(amount) do
        {parsed_amount, _} when not is_nil(parsed_amount) ->
          if Decimal.compare(parsed_amount, Decimal.new("0")) == :gt do
            case Transactions.transfer_funds(from_account, to_account, parsed_amount, user_scope) do
              {:ok, {_updated_from_account, _updated_to_account, _transaction}} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Transfer successful! ZMW #{amount} has been sent to #{to_account.user.email}.")
                 |> redirect(to: ~p"/dashboard")}

              {:error, :insufficient_funds} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Insufficient funds. Your account balance is ZMW #{from_account.balance}.")}

              {:error, changeset} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Transfer failed: #{inspect(changeset.errors)}")}
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
  end

  def handle_event("back_to_step", %{"step" => step}, socket) do
    step_num = String.to_integer(step)
    {:noreply,
     assign(socket,
       step: step_num,
       recipient_account: if(step_num < 3, do: nil, else: socket.assigns.recipient_account)
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

  def quick_amounts(balance) do
    amounts = [50, 100, 200, 500]
    amounts
    |> Enum.filter(fn amount -> 
      Decimal.compare(Decimal.new(amount), balance) != :gt
    end)
    |> Enum.take(3)
  end
end
