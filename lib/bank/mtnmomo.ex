defmodule Bank.MtnMomo do
  @moduledoc """
  MTN Mobile Money API integration for payment processing.
  Handles request-to-pay operations, token management, and payment status checking.
  """

  require Logger

  # Token cache using ETS for simple in-memory storage
  @token_table :mtn_momo_tokens

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :permanent,
      type: :worker
    }
  end

  def start_link do
    # Create ETS table for token caching
    :ets.new(@token_table, [:set, :public, :named_table])
    {:ok, self()}
  end

  # Configuration helpers
  defp config, do: Application.get_env(:bank, :mtn_momo)
  defp base_url, do: config()[:base_url]
  defp subscription_key, do: config()[:subscription_key]
  defp target_environment, do: config()[:target_environment]
  defp currency, do: config()[:currency] || "ZMW"
  defp api_user, do: config()[:api_user]
  defp api_key, do: config()[:api_key]

  def request_to_pay(amount, phone_number, external_id \\ nil) do
    reference_id = external_id || generate_reference_id()

    Logger.info("Initiating MoMo payment request: amount=#{amount}, phone=#{phone_number}, ref=#{reference_id}")

    with {:ok, token} <- get_access_token(),
         {:ok, response} <- make_payment_request(amount, phone_number, reference_id, token) do
      Logger.info("MoMo payment request successful: #{reference_id}")
      {:ok, %{reference_id: reference_id, response: response}}
    else
      {:error, reason} = error ->
        Logger.error("MoMo payment request failed: #{inspect(reason)}")
        error
    end
  end

  # Checks the status of a payment request

  def check_payment_status(reference_id) do
    Logger.info("Checking MoMo payment status: #{reference_id}")

    with {:ok, token} <- get_access_token() do
      url = "#{base_url()}/collection/v1_0/requesttopay/#{reference_id}"

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"X-Target-Environment", target_environment()},
        {"Ocp-Apim-Subscription-Key", subscription_key()}
      ]

      case HTTPoison.get(url, headers, timeout: 30_000, recv_timeout: 30_000) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, data} ->
              Logger.info("MoMo payment status retrieved: #{reference_id} - #{data["status"]}")
              {:ok, data}
            {:error, _} ->
              Logger.error("Invalid JSON response from MoMo API: #{body}")
              {:error, "Invalid JSON response"}
          end

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("MoMo API error: #{status_code} - #{body}")
          {:error, "Payment status check failed: HTTP #{status_code}"}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("HTTP request failed: #{inspect(reason)}")
          {:error, "Network error: #{inspect(reason)}"}
      end
    end
  end

  # Private functions

  defp get_access_token do
    case get_cached_token() do
      nil -> generate_new_token()
      token -> {:ok, token}
    end
  end

  defp get_cached_token do
    try do
      case :ets.lookup(@token_table, :access_token) do
        [{:access_token, token, expires_at}] ->
          current_time = System.system_time(:second)
          if current_time < expires_at do
            Logger.debug("Using cached MTN MoMo token")
            token
          else
            Logger.info("Cached MTN MoMo token expired, will generate new one")
            :ets.delete(@token_table, :access_token)
            nil
          end
        [] ->
          Logger.debug("No cached MTN MoMo token found")
          nil
      end
    rescue
      ArgumentError ->
        Logger.warning("Token cache table not found, creating new one")
        :ets.new(@token_table, [:set, :public, :named_table])
        nil
    end
  end

  defp generate_new_token do
    Logger.info("Generating new MTN MoMo access token")

    url = "#{base_url()}/collection/token/"

    # Use Basic Auth with api_user and api_key
    auth_string = Base.encode64("#{api_user()}:#{api_key()}")

    headers = [
      {"Authorization", "Basic #{auth_string}"},
      {"Ocp-Apim-Subscription-Key", subscription_key()},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(url, "", headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"access_token" => token, "expires_in" => expires_in}} ->
            # Cache the token with expiration time (subtract 60 seconds for safety)
            expires_at = System.system_time(:second) + expires_in - 60
            :ets.insert(@token_table, {:access_token, token, expires_at})

            Logger.info("MTN MoMo access token generated successfully, expires in #{expires_in} seconds")
            {:ok, token}

          {:ok, response} ->
            Logger.error("Unexpected token response format: #{inspect(response)}")
            {:error, "Invalid token response format"}

          {:error, _} ->
            Logger.error("Invalid JSON response from token endpoint: #{body}")
            {:error, "Invalid JSON response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("MTN MoMo token generation failed: #{status_code} - #{body}")
        {:error, "Token generation failed: HTTP #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed during token generation: #{inspect(reason)}")
        {:error, "Network error during token generation: #{inspect(reason)}"}
    end
  end

  defp make_payment_request(amount, phone_number, reference_id, token) do
    url = "#{base_url()}/collection/v1_0/requesttopay"

    # Ensure amount is a string and format phone number
    amount_str = to_string(amount)
    formatted_phone = format_phone_number(phone_number)

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"X-Reference-Id", reference_id},
      {"X-Target-Environment", target_environment()},
      {"Ocp-Apim-Subscription-Key", subscription_key()},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "amount" => amount_str,
      "currency" => currency(),
      "externalId" => reference_id,
      "payer" => %{
        "partyIdType" => "MSISDN",
        "partyId" => formatted_phone
      },
      "payerMessage" => "Bank account deposit",
      "payeeNote" => "Deposit to bank account via mobile money"
    }

    Logger.info("Making payment request to: #{url}")
    Logger.debug("Payment request body: #{inspect(body)}")

    case HTTPoison.post(url, Jason.encode!(body), headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 202, headers: _response_headers}} ->
        # 202 Accepted means request was accepted
        Logger.info("Payment request accepted: #{reference_id}")
        {:ok, "Payment request sent successfully"}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("MoMo API error: #{status_code} - #{response_body}")

        # Try to parse error message from response
        error_message = case Jason.decode(response_body) do
          {:ok, %{"message" => msg}} -> msg
          {:ok, %{"error" => error}} -> error
          _ -> "Payment request failed"
        end

        {:error, "#{error_message} (HTTP #{status_code})"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  def format_phone_number(phone_number) do
    # Remove any space
    cleaned = String.replace(phone_number, ~r/[\s\-\+]/, "")


    cond do
      String.starts_with?(cleaned, "260") -> cleaned
      String.starts_with?(cleaned, "09") -> "260" <> String.slice(cleaned, 1..-1//1)
      String.starts_with?(cleaned, "26") -> cleaned
      true -> "260" <> cleaned
    end
  end

  defp generate_reference_id do
    UUID.uuid4()
  end
end
