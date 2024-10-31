defmodule CryptopeerTest do
  use ExUnit.Case
  doctest Cryptopeer

  test "greets the world" do
    assert Cryptopeer.hello() == :world
  end
end
