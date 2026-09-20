defmodule MDExBlockTags.MixProject do
  use Mix.Project

  @version "0.1.0"
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
          "elements using HTML comment markers."
    ]
  end

  def application, do: []

  defp deps do
    [
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
      filter_modules: fn module, _metadata -> module == MDExBlockTags end
    ]
  end
end
