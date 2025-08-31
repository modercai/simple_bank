defmodule Bank.MomoChecker do
  @moduledoc """
  Background worker
  """
  
  use GenServer
  require Logger
  
  alias Bank.{Transactions, Repo}
  alias Bank.Accounts.Transaction
  
  import Ecto.Query
  
  # Check every 30 seconds for pending transactions
  @check_interval 30_000
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Schedule the first check
    schedule_check()
    {:ok, %{}}
  end
  
  @impl true
  def handle_info(:check_pending_transactions, state) do
    check_pending_transactions()
    schedule_check()
    {:noreply, state}
  end
  
  @doc """
  Manually trigger a check of pending transactions.
  """
  def check_now do
    GenServer.cast(__MODULE__, :check_now)
  end
  
  @impl true
  def handle_cast(:check_now, state) do
    check_pending_transactions()
    {:noreply, state}
  end
  
  defp schedule_check do
    Process.send_after(self(), :check_pending_transactions, @check_interval)
  end
  
  defp check_pending_transactions do
    Logger.info("Checking pending MoMo transactions...")
    
    one_minute_ago = DateTime.utc_now() |> DateTime.add(-60, :second)
    
    pending_transactions = 
      from(t in Transaction,
        where: t.type == "deposit" and 
               t.momo_status == "pending" and
               not is_nil(t.momo_reference_id) and
               t.inserted_at < ^one_minute_ago,
        order_by: [asc: t.inserted_at],
        limit: 10  # Process max 10 at a time to avoid overload
      )
      |> Repo.all()
    
    if length(pending_transactions) > 0 do
      Logger.info("Found #{length(pending_transactions)} pending transactions to check")
      
      pending_transactions
      |> Enum.each(&check_transaction_status/1)
    else
      Logger.debug("No pending transactions to check")
    end
  end
  
  defp check_transaction_status(transaction) do
    Logger.info("Checking status for transaction #{transaction.id}, reference: #{transaction.momo_reference_id}")
    
    case Transactions.check_momo_payment_status(transaction) do
      {:ok, updated_transaction} ->
        if updated_transaction.momo_status != "pending" do
          Logger.info("Transaction #{transaction.id} status updated to: #{updated_transaction.momo_status}")
        end
        
      {:error, reason} ->
        Logger.error("Failed to check transaction #{transaction.id}: #{inspect(reason)}")
        
        # If transaction is very old (24+ hours) and still pending, mark as failed
        twenty_four_hours_ago = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60, :second)
        if DateTime.compare(transaction.inserted_at, twenty_four_hours_ago) == :lt do
          Logger.warning("Marking old pending transaction #{transaction.id} as failed due to timeout")
          Transactions.update_transaction_status(transaction, "failed")
        end
    end
  rescue
    error ->
      Logger.error("Exception while checking transaction #{transaction.id}: #{inspect(error)}")
  end
end