# Postgrex.Pgoutput

![CI](https://github.com/drowzy/postgrex_pgoutput/actions/workflows/ci.yml/badge.svg)
[![Hex.pm Version](https://img.shields.io/hexpm/v/postgrex_pgoutput.svg?style=flat-square)](https://hex.pm/packages/postgrex_pgoutput)

Encode / decode Postgres replication messages.

## Usage

See `examples/cdc` for a full example of using `Postgrex.Replication` to implement CDC (Change Data Capture).

## Installation

This package can be installed by adding `postgrex_pgoutput` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:postgrex_pgoutput, "~> 0.1.0"}
  ]
end
```
