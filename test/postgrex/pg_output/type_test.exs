defmodule Postgrex.PgOutput.TypeTest do
  use ExUnit.Case, async: true
  alias Postgrex.PgOutput.Type

  describe "decode/2" do
    test "should handle null values" do
      assert is_nil(Type.decode(nil, Type.type_info(:varchar)))
    end

    test "varchar, timestamp, timestamp, uuid, text should be string" do
      types = [
        {"varchar", :varchar},
        {"text", :text},
        {"2022-10-05 08:10:32.327344", :timestamp},
        {"2022-10-05 08:10:32.327344Z", :timestamptz},
        {"54893836-6bf8-49aa-a0dc-a9f457ec24c5", :uuid}
      ]

      for {data, typeinfo} <- types do
        decoded = Type.decode(data, Type.type_info(typeinfo))
        assert is_binary(decoded)
        assert data == decoded
      end
    end

    test "int2, int4, int8 should be parsed to ints" do
      types = [
        {"1", :int2},
        {"1", :int4},
        {"1", :int8}
      ]

      for {data, typeinfo} <- types do
        assert 1 == Type.decode(data, Type.type_info(typeinfo))
      end
    end

    test "float4, float8 should be parsed to floats" do
      types = [
        {"1.1", :float4},
        {"1.1", :float8}
      ]

      for {data, typeinfo} <- types do
        assert 1.1 == Type.decode(data, Type.type_info(typeinfo))
      end
    end

    test "json, jsonb should be parsed to list | map" do
      {s_d, s_type} = {~s({"a": "b"}), :jsonb}
      {l_d, l_type} = {~s([{"a": "b"}]), :json}
      {e_d, e_type} = {~s({}), :jsonb}

      assert %{"a" => "b"} == Type.decode(s_d, Type.type_info(s_type))
      assert [%{"a" => "b"}] == Type.decode(l_d, Type.type_info(l_type))
      assert %{} == Type.decode(e_d, Type.type_info(e_type))
    end

    test "should, parse bools be parsed to list | map" do
      {s_d, s_type} = {~s({"a": "b"}), :jsonb}
      {l_d, l_type} = {~s([{"a": "b"}]), :json}
      {e_d, e_type} = {~s({}), :jsonb}

      assert %{"a" => "b"} == Type.decode(s_d, Type.type_info(s_type))
      assert [%{"a" => "b"}] == Type.decode(l_d, Type.type_info(l_type))
      assert %{} == Type.decode(e_d, Type.type_info(e_type))
    end

    test "dates should be parsed to dates" do
      assert ~D[2022-01-01] = Type.decode("2022-01-01", Type.type_info(:date))
    end

    test "arrays types" do
      types = [
        {"{varchar,varchar}", :_varchar},
        {"{text,text}", :_text},
        {"{2022-10-05 08:10:32.327344,2021-10-05 08:10:32.327344}", :_timestamp},
        {"{2022-10-05 08:10:32.327344Z,2021-10-05 08:10:32.327344Z", :_timestamptz},
        {"{54893836-6bf8-49aa-a0dc-a9f457ec24c5,54893836-6bf8-49aa-a0dc-a9f457ec24c5}", :_uuid}
      ]

      for {data, typeinfo} <- types do
        decoded = Type.decode(data, Type.type_info(typeinfo))
        assert is_list(decoded)
        assert length(decoded) == 2
      end
    end

    test "jsonb array single element" do
      bin = "{\"{\\\"sender\\\": \\\"pablo\\\"}\"}"

      [%{"sender" => "pablo"}] = Type.decode(bin, Type.type_info(:_jsonb))
    end

    test "jsonb array multiple elements" do
      bin = "{\"{\\\"sender\\\": \\\"pablo\\\"}\",\"{\\\"sender\\\": \\\"arthur\\\"}\"}"

      [%{"sender" => "pablo"}, %{"sender" => "arthur"}] =
        Type.decode(bin, Type.type_info(:_jsonb))
    end
  end
end
