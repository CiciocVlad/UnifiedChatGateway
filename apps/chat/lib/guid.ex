defmodule Chat.Guid do
  # UUID4 has 122 random bits, which is 15.25 bytes
  # so to truly generate the same amount of randomness, 16 bytes must be requested
  # however in this case 4 bits will be padded with non-random zeroes by base64
  # but if 17 bytes are generated every single bit in the result will be truly random
  def new() do
    <<guid::binary-size(22), _::binary>> =
      17
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    guid
  end
end
