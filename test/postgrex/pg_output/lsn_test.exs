defmodule Postgrex.PgOutput.LsnTest do
  use ExUnit.Case, async: true
  alias Postgrex.PgOutput.Lsn

  describe "encode/decode" do
    test "can decode lsn" do
      assert {0, 685_397_688} == Lsn.decode(<<0, 0, 0, 0, 40, 218, 86, 184>>)
    end

    test "can encode lsn" do
      assert <<0, 0, 0, 0, 40, 218, 86, 184>> == Lsn.encode({0, 685_397_688})
    end

    test "can decode string" do
      assert {0, 0} = Lsn.decode_string("0/0")
    end

    test "can decode string with offset" do
      assert {0, 685_397_688} = Lsn.decode_string("0/28DA56B8")
    end

    test "can encode string" do
      assert "0/0" = Lsn.encode_string({0, 0})
    end

    test "can encode string with offset" do
      lsn = "0/28DA56B8"

      lsn2 =
        lsn
        |> Lsn.decode_string()
        |> Lsn.encode_string()

      assert lsn == lsn2
    end
  end
end
