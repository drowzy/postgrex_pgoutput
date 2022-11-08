defmodule Postgrex.PgOutput.MessagesTest do
  use ExUnit.Case
  import Postgrex.PgOutput.Messages

  describe "decode/1" do
    test "primary_keepalive message" do
      msg = <<107, 0, 0, 0, 0, 1, 130, 140, 128, 0, 2, 141, 89, 193, 229, 5, 73, 1>>

      assert msg_primary_keep_alive(
               server_wal: _wal,
               system_clock: clock,
               reply: reply
             ) = decode(msg)

      assert reply == 1
      assert clock == DateTime.add(~U[2022-10-06 10:16:38Z], 38857, :microsecond)
    end

    test "x_log_data message" do
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

    test "begin message" do
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

    test "relation message" do
      msg =
        <<82, 0, 0, 64, 8, 112, 117, 98, 108, 105, 99, 0, 112, 111, 115, 116, 115, 0, 100, 0, 3,
          1, 105, 100, 0, 0, 0, 0, 20, 255, 255, 255, 255, 0, 116, 105, 116, 108, 101, 0, 0, 0, 4,
          19, 0, 0, 1, 3, 0, 98, 111, 100, 121, 0, 0, 0, 4, 19, 0, 0, 1, 3>>

      assert msg_relation(
               id: 16392,
               namespace: "public",
               name: "posts",
               replica_identity: :default,
               columns: [
                 column(
                   flags: [:key],
                   name: "id",
                   type: "int8",
                   modifier: -1
                 ),
                 column(
                   flags: [],
                   name: "title",
                   type: "varchar",
                   modifier: 259
                 ),
                 column(
                   flags: [],
                   name: "body",
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
        <<73, 0, 0, 64, 8, 78, 0, 3, 116, 0, 0, 0, 1, 57, 116, 0, 0, 0, 5, 116, 105, 116, 108,
          101, 116, 0, 0, 0, 4, 98, 111, 100, 121>>

      assert msg_insert(relation_id: 16392, data: ["9", "title", "body"]) == decode(msg)
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

    test "update with REPLICA IDENTITY INDEX" do
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

    test "update with REPLICA IDENTITY FULL" do
      msg =
        <<85, 0, 0, 64, 8, 79, 0, 3, 116, 0, 0, 0, 1, 53, 116, 0, 0, 0, 7, 99, 104, 97, 110, 103,
          101, 100, 116, 0, 0, 0, 8, 110, 101, 119, 32, 98, 111, 100, 121, 78, 0, 3, 116, 0, 0, 0,
          1, 53, 116, 0, 0, 0, 7, 99, 104, 97, 110, 103, 101, 100, 116, 0, 0, 0, 4, 98, 111, 100,
          121>>

      assert decode(msg) ==
               msg_update(
                 relation_id: 16392,
                 change_data: ["5", "changed", "body"],
                 old_data: ["5", "changed", "new body"],
                 change_type: :full
               )
    end

    test "delete with REPLICA IDENTITY INDEX" do
      msg = <<68, 0, 0, 64, 8, 75, 0, 3, 116, 0, 0, 0, 1, 53, 110, 110>>

      assert decode(msg) ==
               msg_delete(
                 relation_id: 16392,
                 old_data: ["5", nil, nil],
                 change_type: :index
               )
    end

    test "delete with REPLICA IDENTITY FULL" do
      msg =
        <<68, 0, 0, 64, 8, 79, 0, 3, 116, 0, 0, 0, 1, 57, 116, 0, 0, 0, 5, 116, 105, 116, 108,
          101, 116, 0, 0, 0, 4, 98, 111, 100, 121>>

      assert decode(msg) ==
               msg_delete(
                 relation_id: 16392,
                 old_data: ["9", "title", "body"],
                 change_type: :full
               )
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
