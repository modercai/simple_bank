defmodule BankWeb.AdminLive.Transactions do
  use BankWeb, :live_view

  alias Bank.Transactions
  alias Bank.Accounts

  def mount(_params, _session, socket) do
    # Initialize with default pagination and filters
    filters = %{
      page: 1,
      per_page: 10,
      user_id: nil,
      date_from: nil,
      date_to: nil,
      type: "all"
    }

    {transactions, pagination} = Transactions.list_transactions_paginated(filters)

    {:ok,
      assign(socket,
        users: Accounts.list_customers(),
        transactions: transactions,
        pagination: pagination,
        filters: filters,
        filter_form: to_form(%{
          "user_id" => "",
          "date_from" => "",
          "date_to" => "",
          "type" => "all"
        })
      )
    }
  end

  def handle_event("filter", params, socket) do
    filters = %{
      page: 1, # Reset to first page when filtering
      per_page: 10,
      user_id: if(params["user_id"] == "", do: nil, else: params["user_id"]),
      date_from: parse_date(params["date_from"]),
      date_to: parse_date(params["date_to"]),
      type: params["type"] || "all"
    }

    {transactions, pagination} = Transactions.list_transactions_paginated(filters)

    {:noreply,
      assign(socket,
        transactions: transactions,
        pagination: pagination,
        filters: filters,
        filter_form: to_form(params)
      )
    }
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    filters = Map.put(socket.assigns.filters, :page, page)

    {transactions, pagination} = Transactions.list_transactions_paginated(filters)

    {:noreply,
      assign(socket,
        transactions: transactions,
        pagination: pagination,
        filters: filters
      )
    }
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00])
      _ -> nil
    end
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
      type when type in ["withdrawal", "transfer_out"] -> ""
      _ -> ""
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
