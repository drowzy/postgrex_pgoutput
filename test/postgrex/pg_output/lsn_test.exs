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
      assert {0, 0} == Lsn.decode_string("0/0")
    end

    test "can decode string with offset" do
      assert {0, 685_397_688} == Lsn.decode_string("0/28DA56B8")
    end

    test "can encode string" do
      assert "0/0" == Lsn.encode_string({0, 0})
    end

    test "can encode string with offset" do
      lsn = "0/28DA56B8"

      lsn2 =
        lsn
        |> Lsn.decode_string()
        |> Lsn.encode_string()

      assert lsn == lsn2
    end

    @tag :focus
    test "can handle values in the unsigned range" do
      assert Lsn.encode_int64({0, 4_294_967_295}) == 4_294_967_295
      assert Lsn.decode(Lsn.encode({0, 4_294_967_295})) == Lsn.decode_string("0/FFFFFFFF")
    end
  end
end
