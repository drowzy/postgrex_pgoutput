defmodule Postgrex.PgOutput.MessagesTest do
  use ExUnit.Case
  import Postgrex.PgOutput.Messages

  describe "decode/1" do
    test "primary_keepalive msg" do
      msg = <<107, 0, 0, 0, 0, 1, 130, 140, 128, 0, 2, 141, 89, 193, 229, 5, 73, 1>>

      assert msg_primary_keep_alive(
               server_wal: _wal,
               system_clock: clock,
               reply: reply
             ) = decode(msg)

      assert reply == 1
      assert clock == DateTime.add(~U[2022-10-06 10:16:38Z], 38857, :microsecond)
    end

    test "x_log_data msg" do
      msg =
        <<119, 0, 0, 0, 0, 1, 94, 109, 184, 0, 0, 0, 0, 1, 94, 109, 184, 0, 2, 141, 89, 243, 12,
          106, 120>>

      assert msg_xlog_data(
               start_lsn: {0, 22_965_688},
               end_lsn: {0, 22_965_688},
               system_clock: DateTime.add(~U[2022-10-06 10:30:22Z], 704_248, :microsecond),
               data: msg_empty([])
             ) == decode(msg)
    end

    test "begin msg" do
      ts = DateTime.add(~U[2021-11-24 15:18:42Z], 571_691, :microsecond)
      lsn = {0, 685_397_688}

      msg = <<66, 0, 0, 0, 0, 40, 218, 86, 184, 0, 2, 116, 137, 36, 88, 241, 171, 0, 6, 166, 173>>
      assert msg_begin(timestamp: ts, lsn: lsn, xid: 435_885) == decode(msg)
    end

    test "commit msg" do
      msg =
        <<67, 0, 0, 0, 0, 0, 40, 218, 86, 184, 0, 0, 0, 0, 40, 218, 86, 232, 0, 2, 116, 137, 36,
          88, 241, 171>>

      assert msg_commit(
               flags: [],
               lsn: {0, 685_397_688},
               end_lsn: {0, 685_397_736},
               timestamp: DateTime.add(~U[2021-11-24 15:18:42Z], 571_691, :microsecond)
             ) == decode(msg)
    end

    test "relation msg" do
      msg =
        <<82, 0, 0, 175, 141, 112, 117, 98, 108, 105, 99, 0, 114, 101, 112, 108, 95, 116, 0, 100,
          0, 2, 0, 97, 0, 0, 0, 0, 23, 255, 255, 255, 255, 0, 98, 0, 0, 0, 4, 19, 0, 0, 1, 3>>

      assert msg_relation(
               id: 44941,
               namespace: "public",
               name: "repl_t",
               replica_identity: :default,
               columns: [
                 column(
                   flags: [],
                   name: "a",
                   type: "int4",
                   modifier: -1
                 ),
                 column(
                   flags: [],
                   name: "b",
                   type: "varchar",
                   modifier: 259
                 )
               ]
             ) == decode(msg)
    end

    test "origin msg" do
      msg = <<79, 0, 0, 0, 0, 40, 216, 245, 168, 115, 101, 114, 118, 101, 114>>
      assert msg_origin(lsn: {0, 685_307_304}, name: "server") == decode(msg)
    end

    # TODO null or toasted values test
    test "insert msg" do
      msg =
        <<73, 0, 0, 175, 141, 78, 0, 2, 116, 0, 0, 0, 1, 49, 116, 0, 0, 0, 6, 102, 111, 111, 98,
          97, 114>>

      assert msg_insert(relation_id: 44941, data: ["1", "foobar"]) = decode(msg)
    end

    test "update msg" do
      msg =
        <<85, 0, 0, 175, 155, 78, 0, 3, 116, 0, 0, 0, 1, 49, 116, 0, 0, 0, 1, 49, 116, 0, 0, 0, 6,
          117, 112, 100, 97, 116, 101>>

      assert msg_update(
               relation_id: 44955,
               old_data: [],
               change_data: ["1", "1", "update"],
               change_type: :default
             ) = decode(msg)
    end

    test "update msg replica = index" do
      msg =
        <<85, 0, 0, 175, 155, 75, 0, 3, 116, 0, 0, 0, 1, 51, 110, 110, 78, 0, 3, 116, 0, 0, 0, 1,
          52, 116, 0, 0, 0, 1, 49, 116, 0, 0, 0, 15, 117, 112, 100, 97, 116, 101, 95, 105, 100,
          101, 110, 116, 105, 116, 121>>

      assert msg_update(
               relation_id: 44955,
               old_data: ["3", nil, nil],
               change_data: ["4", "1", "update_identity"],
               change_type: :index
             ) = decode(msg)
    end

    test "update msg replica = full" do
      msg =
        <<85, 0, 0, 175, 161, 79, 0, 2, 116, 0, 0, 0, 1, 49, 116, 0, 0, 0, 6, 105, 110, 115, 101,
          114, 116, 78, 0, 2, 116, 0, 0, 0, 1, 49, 116, 0, 0, 0, 6, 117, 112, 100, 97, 116, 101>>

      assert msg_update(
               relation_id: 44961,
               old_data: ["1", "insert"],
               change_data: ["1", "update"],
               change_type: :full
             ) = decode(msg)
    end

    test "delete msg replica = index" do
      msg = <<68, 0, 0, 175, 155, 75, 0, 3, 116, 0, 0, 0, 1, 50, 110, 110>>

      assert msg_delete(
               relation_id: 44955,
               old_data: ["2", nil, nil],
               change_type: :index
             ) == decode(msg)
    end

    test "delete msg replica = full" do
      msg =
        <<68, 0, 0, 175, 161, 79, 0, 2, 116, 0, 0, 0, 1, 49, 116, 0, 0, 0, 6, 117, 112, 100, 97,
          116, 101>>

      assert msg_delete(
               relation_id: 44961,
               old_data: ["1", "update"],
               change_type: :full
             ) == decode(msg)
    end

    test "truncate msg" do
      msg = <<84, 0, 0, 0, 1, 0, 0, 0, 175, 155>>

      assert msg_truncate(opts: :none, relation_ids: [44955]) = decode(msg)
    end

    test "truncate msg cascade" do
      msg = <<84, 0, 0, 0, 1, 1, 0, 0, 175, 155>>

      assert msg_truncate(opts: :cascade, relation_ids: [44955]) = decode(msg)
    end

    test "truncate msg restart identity" do
      msg = <<84, 0, 0, 0, 1, 2, 0, 0, 175, 155>>

      assert msg_truncate(opts: :restart_identity, relation_ids: [44955]) = decode(msg)
    end

    test "type msg" do
      msg =
        <<89, 0, 0, 128, 52, 112, 117, 98, 108, 105, 99, 0, 101, 120, 97, 109, 112, 108, 101, 95,
          116, 121, 112, 101, 0>>

      assert msg_type(id: 32820, namespace: "public", name: "example_type") == decode(msg)
    end
  end
end
