defmodule MDExBlockTags.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/kioopi/mdex_block_tags"

  def project do
    [
      app: :mdex_block_tags,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "MDExBlockTags",
      source_url: @source_url,
      description:
        "An MDEx plugin that wraps Markdown content in semantic HTML block " <>
          "elements using HTML comment markers.",
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_core_path: "priv/plts/core",
        plt_local_path: "priv/plts"
      ],
      aliases: aliases()
    ]
  end

  def application, do: []

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:mdex, "~> 0.13"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      filter_modules: fn module, _metadata ->
        module in [MDExBlockTags, MDExBlockTags.Handler, MDExBlockTags.Marker]
      end
    ]
  end

  defp aliases() do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end
end
