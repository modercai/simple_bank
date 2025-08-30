defmodule Bank.MtnMomo do

  require Logger

  @base_url "https://sandbox.momodeveloper.mtn.com"
  @subscription_key "70a027b279b6428ca26edd3211642ae1"
  @target_environment "sandbox"

  def request_to_pay(amount, phone_number, external_id \\ nil) do
    reference_id = external_id || generate_reference_id()

    with {:ok, token} <- get_access_token(),
         {:ok, response} <- make_payment_request(amount, phone_number, reference_id, token) do
      {:ok, %{reference_id: reference_id, response: response}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def check_payment_status(reference_id) do
    with {:ok, token} <- get_access_token() do
      url = "#{@base_url}/collection/v1_0/requesttopay/#{reference_id}"

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"X-Target-Environment", @target_environment},
        {"Ocp-Apim-Subscription-Key", @subscription_key},
        {"Content-Type", "application/json"}
      ]

      case HTTPoison.get(url, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, data} -> {:ok, data}
            {:error, _} -> {:error, "Invalid JSON response"}
          end

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("MoMo API error: #{status_code} - #{body}")
          {:error, "Payment status check failed"}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("HTTP request failed: #{inspect(reason)}")
          {:error, "Network error"}
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
    {:ok, "your_generated_token_here"}
  end

  defp make_payment_request(amount, phone_number, reference_id, token) do
    url = "#{@base_url}/collection/v1_0/requesttopay"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"X-Reference-Id", reference_id},
      {"X-Target-Environment", @target_environment},
      {"Ocp-Apim-Subscription-Key", @subscription_key},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "amount" => to_string(amount),
      "currency" => "EUR",
      "externalId" => reference_id,
      "payer" => %{
        "partyIdType" => "MSISDN",
        "partyId" => phone_number
      },
      "payerMessage" => "Deposit to account",
      "payeeNote" => "Account deposit via mobile money"
    }

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 202}} ->
        {:ok, "Payment request sent successfully"}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("MoMo API error: #{status_code} - #{response_body}")
        {:error, "Payment request failed"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Network error"}
    end
  end

  defp generate_reference_id do
    UUID.uuid4()
  end
end
