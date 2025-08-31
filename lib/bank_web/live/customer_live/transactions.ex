defmodule BankWeb.CustomerLive.Transactions do
  use BankWeb, :live_view

  alias Bank.Transactions

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    accounts = get_user_accounts(user.id)
    
    # Initialize with default pagination and filters
    filters = %{
      page: 1,
      per_page: 10,
      user_id: user.id, # Only this user's transactions
      date_from: nil,
      date_to: nil,
      type: "all"
    }
    
    {transactions, pagination} = Transactions.list_transactions_paginated(filters)
    
    {:ok,
     assign(socket,
       accounts: accounts,
       transactions: transactions,
       pagination: pagination,
       filters: filters,
       selected_account_id: nil,
       filter_form: to_form(%{
         "account_id" => "",
         "date_from" => "",
         "date_to" => "",
         "type" => "all"
       })
     )
    }
  end

  def handle_event("filter", params, socket) do
    user = socket.assigns.current_scope.user
    
    # Build filters with user restriction
    filters = %{
      page: 1, # Reset to first page when filtering
      per_page: 10,
      user_id: user.id, # Always restrict to current user
      date_from: parse_date(params["date_from"]),
      date_to: parse_date(params["date_to"]),
      type: params["type"] || "all"
    }
    
    # Handle account filtering (customer can filter by their own accounts)
    account_id = if params["account_id"] == "", do: nil, else: params["account_id"]
    
    # If account is selected, use different query method
    {transactions, pagination} = if account_id do
      # Custom pagination for account-specific transactions
      get_account_transactions_paginated(account_id, filters)
    else
      Transactions.list_transactions_paginated(filters)
    end
    
    {:noreply,
      assign(socket,
        transactions: transactions,
        pagination: pagination,
        filters: filters,
        selected_account_id: account_id,
        filter_form: to_form(params)
      )
    }
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    filters = Map.put(socket.assigns.filters, :page, page)
    
    {transactions, pagination} = if socket.assigns.selected_account_id do
      get_account_transactions_paginated(socket.assigns.selected_account_id, filters)
    else
      Transactions.list_transactions_paginated(filters)
    end
    
    {:noreply,
      assign(socket,
        transactions: transactions,
        pagination: pagination,
        filters: filters
      )
    }
  end

  defp get_account_transactions_paginated(account_id, filters) do
    import Ecto.Query
    
    page = Map.get(filters, :page, 1)
    per_page = Map.get(filters, :per_page, 10)
    date_from = Map.get(filters, :date_from)
    date_to = Map.get(filters, :date_to)
    transaction_type = Map.get(filters, :type)
    
    query = from t in Bank.Accounts.Transaction,
      where: t.account_id == ^account_id or t.to_account_id == ^account_id,
      order_by: [desc: t.inserted_at]
    
    # Apply date filters
    query = if date_from do
      where(query, [t], t.inserted_at >= ^date_from)
    else
      query
    end
    
    query = if date_to do
      end_date = Date.add(date_to, 1) |> DateTime.new!(~T[00:00:00])
      where(query, [t], t.inserted_at < ^end_date)
    else
      query
    end
    
    # Apply type filter
    query = if transaction_type && transaction_type != "all" do
      where(query, [t], t.type == ^transaction_type)
    else
      query
    end
    
    # Get total count
    total_count = Bank.Repo.aggregate(query, :count)
    total_pages = ceil(total_count / per_page)
    
    # Get paginated results
    offset = (page - 1) * per_page
    transactions = query
    |> limit(^per_page)
    |> offset(^offset)
    |> preload([:user])
    |> Bank.Repo.all()
    
    pagination_info = %{
      total_count: total_count,
      total_pages: total_pages,
      current_page: page,
      per_page: per_page,
      has_prev: page > 1,
      has_next: page < total_pages
    }
    
    {transactions, pagination_info}
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00])
      _ -> nil
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

  def transaction_type_display(type) do
    case type do
      "withdrawal" -> "Withdrawal"
      "transfer_in" -> "Transfer Received"
      "transfer_out" -> "Transfer Sent"
      "deposit" -> "Deposit"
      _ -> String.replace(type, "_", " ") |> String.capitalize()
    end
  end

  def transaction_amount_class(type) do
    case type do
      type when type in ["withdrawal", "transfer_out"] -> "text-red-600"
      _ -> "text-green-600"
    end
  end

  def transaction_amount_prefix(type) do
    case type do
      type when type in ["withdrawal", "transfer_out"] -> "-"
      _ -> "+"
    end
  end

  def format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
