defmodule Postgrex.PgOutput.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/drowzy/postgrex_pgoutput"
  @description "Decode / encode Postgres replication messages"

  def project do
    [
      app: :postgrex_pgoutput,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: @description,
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "Postgrex.PgOutput",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Simon Thörnqvist"],
      licenses: ["MIT"],
      files: ~w(
        mix.exs
        README.md
        lib/postgrex
        LICENSE
        .formatter.exs
      ),
      links: %{"GitHub" => @source_url}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:postgrex, "~> 0.19", optional: true},
      {:jason, "~> 1.2", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
