defmodule Postgrex.Pgoutput.MixProject do
  use Mix.Project

  def project do
    [
      app: :postgrex_pgoutput,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:postgrex, "~> 0.16.5", optional: true},
      {:jason, "~> 1.2", optional: true}
    ]
  end
end
