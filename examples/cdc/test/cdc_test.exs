defmodule CdcTest do
  use ExUnit.Case
  doctest Cdc

  test "greets the world" do
    assert Cdc.hello() == :world
  end
end
