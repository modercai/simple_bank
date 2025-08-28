defmodule BankWeb.AdminLive.Customers do
  use BankWeb, :live_view

  alias Bank.Accounts
  alias Bank.Accounts.User

  def mount(_params, _session, socket) do
    changeset = Accounts.change_customer(%User{})
    {:ok,
      assign(socket,
        customers: Accounts.list_customers(),
        changeset: changeset,
        form: to_form(changeset)
      )
    }
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    # Set a default role if not provided
    user_params = Map.put_new(user_params, "role", "customer")

    case Accounts.create_customer(user_params) do
      {:ok, _customer} ->
        changeset = Accounts.change_customer(%User{})
        {:noreply,
          socket
          |> put_flash(:info, "Customer created successfully")
          |> assign(
            customers: Accounts.list_customers(),
            changeset: changeset,
            form: to_form(changeset)
          )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Error creating customer")
          |> assign(changeset: changeset, form: to_form(changeset))}
    end
  end

  def handle_event("block", %{"id" => id}, socket) do
    Accounts.set_user_status(id, "blocked")
    {:noreply, assign(socket, customers: Accounts.list_customers())}
  end

  def handle_event("unblock", %{"id" => id}, socket) do
    Accounts.set_user_status(id, "active")
    {:noreply, assign(socket, customers: Accounts.list_customers())}
  end
end
