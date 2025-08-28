defmodule BankWeb.AdminLive.Accounts.New do
  use BankWeb, :live_view
  require Logger

  alias Bank.Accounts
  alias Bank.Accounts.Account

  def mount(%{"user_id" => user_id} = _params, _session, socket) do
    Logger.info("Mounting with user_id: #{user_id}")
    user = Accounts.get_user!(user_id)
    account_number = Account.generate_account_number()

    changeset =
      %Account{}
      |> Account.changeset(%{
        "user_id" => user_id,
        "number" => account_number,
        "type" => "savings",
        "balance" => "0.00"
      })

    Logger.info("Initial changeset: #{inspect(changeset)}")

    {:ok,
     assign(socket,
       user: user,
       account_changeset: changeset,
       form: to_form(changeset)
     )}
  end

  def handle_event("save", %{"account" => account_params} = params, socket) do
    Logger.info("Save event received with params: #{inspect(params)}")
    Logger.info("Account params: #{inspect(account_params)}")

    # Ensure user_id is present and convert to integer
    account_params = Map.put(account_params, "user_id", socket.assigns.user.id)
    
    # Ensure balance is a string if it's not already
    account_params = case account_params do
      %{"balance" => balance} when is_number(balance) ->
        Map.put(account_params, "balance", to_string(balance))
      _ -> account_params
    end

    case Accounts.create_account(account_params) do
      {:ok, account} ->
        Logger.info("Account created successfully: #{inspect(account)}")
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully")
         |> redirect(to: ~p"/admin/customers")}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Account creation failed: #{inspect(changeset.errors)}")
        {:noreply,
         socket
         |> put_flash(:error, "Error creating account: #{inspect(changeset.errors)}")
         |> assign(account_changeset: changeset, form: to_form(changeset))}
    end
  end
end
