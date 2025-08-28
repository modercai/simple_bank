defmodule BankWeb.AdminLive.Accounts do
  use BankWeb, :live_view

  alias Bank.Accounts
  alias Bank.Accounts.Account

  def mount(_params, _session, socket) do
    users = Accounts.list_customers()
    accounts = Accounts.list_accounts()
    
    account_changeset = Accounts.change_account(%Account{})
    fund_form = to_form(%{"amount" => "", "account_id" => ""})

    {:ok,
      assign(socket,
        users: users,
        accounts: accounts,
        account_changeset: account_changeset,
        account_form: to_form(account_changeset),
        fund_form: fund_form,
        selected_user_id: nil,
        selected_account_for_funding: nil
      )
    }
  end

  def handle_event("create_account", %{"account" => account_params}, socket) do
    # Generate account number 
    account_params = if account_params["number"] == "" or account_params["number"] == nil do
      Map.put(account_params, "number", Account.generate_account_number())
    else
      account_params
    end

    case Accounts.create_account(account_params) do
      {:ok, _account} ->
        accounts = Accounts.list_accounts()
        account_changeset = Accounts.change_account(%Account{})
        {:noreply,
          socket
          |> put_flash(:info, "Account created successfully")
          |> assign(
            accounts: accounts,
            account_changeset: account_changeset,
            account_form: to_form(account_changeset),
            selected_user_id: nil
          )
        }
      {:error, account_changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Error creating account")
          |> assign(
            account_changeset: account_changeset,
            account_form: to_form(account_changeset),
            selected_user_id: account_params["user_id"]
          )
        }
    end
  end

  def handle_event("fund_account", %{"amount" => amount, "account_id" => account_id}, socket) do
    account = Accounts.get_account!(account_id)
    
    case Accounts.fund_account(account, %{"amount" => amount}) do
      {:ok, _updated_account} ->
        accounts = Accounts.list_accounts()
        fund_form = to_form(%{"amount" => "", "account_id" => ""})
        {:noreply,
          socket
          |> put_flash(:info, "Account funded successfully")
          |> assign(
            accounts: accounts,
            fund_form: fund_form,
            selected_account_for_funding: nil
          )
        }
      {:error, changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Error funding account: #{inspect(changeset.errors)}")
        }
    end
  end

  def handle_event("select_account_for_funding", %{"account_id" => account_id}, socket) do
    fund_form = to_form(%{"amount" => "", "account_id" => account_id})
    selected_account = if account_id == "" do
      nil
    else
      String.to_integer(account_id)
    end
    
    {:noreply,
      assign(socket,
        fund_form: fund_form,
        selected_account_for_funding: selected_account
      )
    }
  end
end
