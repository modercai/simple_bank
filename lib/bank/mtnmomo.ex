defmodule Bank.MtnMomo do

  require Logger

  defp config, do: Application.get_env(:bank, :mtn_momo)
  defp base_url, do: config()[:base_url]
  defp subscription_key, do: config()[:subscription_key]
  defp target_environment, do: config()[:target_environment]
  defp currency, do: config()[:currency] || "ZMW"

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

  def check_payment_status(reference_id) do
    Logger.info("Checking MoMo payment status: #{reference_id}")
    
    with {:ok, token} <- get_access_token() do
      url = "#{base_url()}/collection/v1_0/requesttopay/#{reference_id}"

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"X-Target-Environment", target_environment()},
        {"Ocp-Apim-Subscription-Key", subscription_key()},
        {"Content-Type", "application/json"}
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
  
  defp get_access_token do
    
    case get_cached_token() do
      nil -> generate_new_token()
      token -> {:ok, token}
    end
  end

  defp get_cached_token do

    nil
  end

  defp generate_new_token do
    # token 
    case config()[:access_token] do
      nil ->
        Logger.error("No access token configured for MTN MoMo")
        {:error, "No access token configured"}
      
      token ->
        Logger.info("Using configured JWT token for MTN MoMo API")
        {:ok, token}
    end
  end

  defp make_payment_request(amount, phone_number, reference_id, token) do
    url = "#{base_url()}/collection/v1_0/requesttopay"
    
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

  def format_phone_number(phone_number) do # sems to be wrong and not working fix for later
  
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