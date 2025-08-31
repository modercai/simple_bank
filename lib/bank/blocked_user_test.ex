defmodule Bank.BlockedUserTest do
  @moduledoc """
  Simple test module to verify that blocked users cannot log in.
  """
  
  alias Bank.{Accounts, Repo}
  alias Bank.Accounts.User
  import Ecto.Query
  require Logger
  
  def test_blocked_user_login do
    Logger.info("Testing blocked user login prevention...")
    
    # Create a test user
    user_attrs = %{
      email: "test@example.com",
      password: "supersecretpassword123",
      nrc: "123456789",
      role: "customer"
    }
    
    # Clean up any existing test user
    Repo.delete_all(from u in User, where: u.email == "test@example.com")
    
    case Accounts.create_customer(user_attrs) do
      {:ok, user} ->
        run_tests(user)
        
      {:error, changeset} ->
        Logger.error("❌ Failed to create test user: #{inspect(changeset.errors)}")
        {:error, "Failed to create test user"}
    end
  rescue
    error ->
      Logger.error("❌ Test failed with exception: #{inspect(error)}")
      {:error, "Test failed with exception"}
  end
  
  defp run_tests(user) do
    Logger.info("✅ Test user created: #{user.email}")
    
    with :ok <- test_normal_login(),
         :ok <- test_block_user(user),
         :ok <- test_blocked_login(),
         blocked_user <- Accounts.get_user!(user.id),
         :ok <- test_password_validation(blocked_user),
         :ok <- test_unblock_and_login(blocked_user) do
      
      # Clean up
      Repo.delete(user)
      Logger.info("🧹 Test user cleaned up")
      
      Logger.info("🎉 All tests passed! Blocked user functionality working correctly.")
      {:ok, "All tests passed"}
    else
      error -> error
    end
  end
  
  defp test_normal_login do
    case Accounts.get_user_by_email_and_password("test@example.com", "supersecretpassword123") do
      %User{} = _user ->
        Logger.info("✅ Normal login works for active user")
        :ok
        
      nil ->
        Logger.error("❌ Normal login failed for active user")
        {:error, "Normal login failed"}
    end
  end
  
  defp test_block_user(user) do
    case Accounts.block_user(user) do
      {:ok, blocked_user} ->
        Logger.info("✅ User blocked successfully. Status: #{blocked_user.status}")
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to block user: #{inspect(reason)}")
        {:error, "Failed to block user"}
    end
  end
  
  defp test_blocked_login do
    case Accounts.get_user_by_email_and_password("test@example.com", "supersecretpassword123") do
      nil ->
        Logger.info("✅ Login correctly denied for blocked user")
        :ok
        
      %User{} = _user ->
        Logger.error("❌ Login should have been denied for blocked user")
        {:error, "Blocked user was able to login"}
    end
  end
  
  defp test_password_validation(blocked_user) do
    case User.valid_password?(blocked_user, "supersecretpassword123") do
      false ->
        Logger.info("✅ Password validation correctly returns false for blocked user")
        :ok
        
      true ->
        Logger.error("❌ Password validation should return false for blocked user")
        {:error, "Password validation failed for blocked user"}
    end
  end
  
  defp test_unblock_and_login(blocked_user) do
    case Accounts.unblock_user(blocked_user) do
      {:ok, unblocked_user} ->
        Logger.info("✅ User unblocked successfully. Status: #{unblocked_user.status}")
        
        case Accounts.get_user_by_email_and_password("test@example.com", "supersecretpassword123") do
          %User{} = _user ->
            Logger.info("✅ Login works again after unblocking")
            :ok
            
          nil ->
            Logger.error("❌ Login should work after unblocking")
            {:error, "Login failed after unblocking"}
        end
        
      {:error, reason} ->
        Logger.error("❌ Failed to unblock user: #{inspect(reason)}")
        {:error, "Failed to unblock user"}
    end
  end
end