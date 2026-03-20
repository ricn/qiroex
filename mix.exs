defmodule Qiroex.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/ricn/qiroex"
  @docs_url "https://hexdocs.pm/qiroex"
  @changelog_url "#{@source_url}/blob/main/CHANGELOG.md"

  def project do
    [
      app: :qiroex,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Pure-Elixir QR code generator with zero dependencies — SVG, PNG, and terminal output with styling and logo support.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => @docs_url,
        "Changelog" => @changelog_url
      },
      files: ~w(lib assets mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "Qiroex",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
