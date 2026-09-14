defmodule Phoenix.Token do
  @moduledoc """
  A token test double: models scheme, payload, and age, with NO cryptography.
  Only decodes tokens created by this demo; never use it for authentication.
  """

  def sign(context, salt, data, opts \\ []),
    do: encode(:signed, context, salt, data, opts)

  def encrypt(context, salt, data, opts \\ []),
    do: encode(:encrypted, context, salt, data, opts)

  def verify(context, salt, token, opts \\ []),
    do: decode(:signed, context, salt, token, opts)

  def decrypt(context, salt, token, opts \\ []),
    do: decode(:encrypted, context, salt, token, opts)

  defp encode(scheme, context, salt, data, opts) do
    signed_at = Keyword.get(opts, :signed_at, System.system_time(:second))
    :erlang.term_to_binary({scheme, context, salt, data, signed_at})
  end

  defp decode(scheme, context, salt, token, opts) do
    case :erlang.binary_to_term(token, [:safe]) do
      {^scheme, ^context, ^salt, data, signed_at} ->
        max_age = Keyword.get(opts, :max_age, 86_400)

        if max_age == :infinity or System.system_time(:second) - signed_at < max_age,
          do: {:ok, data},
          else: {:error, :expired}

      _other ->
        {:error, :invalid}
    end
  end
end
