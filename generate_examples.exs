#!/usr/bin/env elixir
# Script to generate example QR code images for the README

alias Qiroex.Style
alias Qiroex.Logo

out = "assets"
File.mkdir_p!(out)

IO.puts("Generating example QR codes...")

# ── 1. Basic QR code ──────────────────────────────────────────────
Qiroex.save_svg("https://github.com/ricn/qiroex", "#{out}/basic.svg",
  module_size: 8, quiet_zone: 2)
IO.puts("  ✓ basic.svg")

# ── 2. Custom colors ─────────────────────────────────────────────
Qiroex.save_svg("https://elixir-lang.org", "#{out}/colors.svg",
  module_size: 8, quiet_zone: 2,
  dark_color: "#4B275F", light_color: "#F4F1F6")
IO.puts("  ✓ colors.svg")

# ── 3. Circle modules ───────────────────────────────────────────
style_circles = Style.new(module_shape: :circle)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/circles.svg",
  module_size: 8, quiet_zone: 2, style: style_circles)
IO.puts("  ✓ circles.svg")

# ── 4. Rounded modules ──────────────────────────────────────────
style_rounded = Style.new(module_shape: :rounded, module_radius: 0.4)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/rounded.svg",
  module_size: 8, quiet_zone: 2, style: style_rounded)
IO.puts("  ✓ rounded.svg")

# ── 5. Diamond modules ──────────────────────────────────────────
style_diamond = Style.new(module_shape: :diamond)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/diamond.svg",
  module_size: 8, quiet_zone: 2, style: style_diamond)
IO.puts("  ✓ diamond.svg")

# ── 6. Finder pattern colors ────────────────────────────────────
style_finder = Style.new(
  module_shape: :rounded,
  module_radius: 0.3,
  finder: %{outer: "#E63946", inner: "#F1FAEE", eye: "#1D3557"}
)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/finder_colors.svg",
  module_size: 8, quiet_zone: 2, style: style_finder)
IO.puts("  ✓ finder_colors.svg")

# ── 7. Linear gradient ──────────────────────────────────────────
style_gradient = Style.new(
  module_shape: :circle,
  gradient: %{type: :linear, start_color: "#667EEA", end_color: "#764BA2", angle: 135}
)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/gradient.svg",
  module_size: 8, quiet_zone: 2, style: style_gradient)
IO.puts("  ✓ gradient.svg")

# ── 8. Radial gradient ──────────────────────────────────────────
style_radial = Style.new(
  module_shape: :rounded,
  module_radius: 0.3,
  gradient: %{type: :radial, start_color: "#F093FB", end_color: "#F5576C"}
)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/radial.svg",
  module_size: 8, quiet_zone: 2, style: style_radial)
IO.puts("  ✓ radial.svg")

# ── 9. Full styled (gradient + finder colors + shape) ────────────
style_full = Style.new(
  module_shape: :circle,
  finder: %{outer: "#2D3436", inner: "#FFFFFF", eye: "#E17055"},
  gradient: %{type: :linear, start_color: "#2D3436", end_color: "#636E72", angle: 45}
)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/styled.svg",
  module_size: 8, quiet_zone: 2, style: style_full)
IO.puts("  ✓ styled.svg")

# ── 10. Logo embedding ──────────────────────────────────────────
elixir_logo_svg = ~s"""
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="eg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#9B59B6"/>
      <stop offset="100%" stop-color="#4B275F"/>
    </linearGradient>
  </defs>
  <circle cx="50" cy="50" r="45" fill="url(#eg)"/>
  <text x="50" y="62" text-anchor="middle" font-size="36" font-weight="bold" fill="white" font-family="sans-serif">Ex</text>
</svg>
"""

logo = Logo.new(svg: elixir_logo_svg, size: 0.22, shape: :circle, padding: 1)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/logo.svg",
  module_size: 8, quiet_zone: 2, level: :h, logo: logo)
IO.puts("  ✓ logo.svg")

# ── 11. Logo with styled QR ─────────────────────────────────────
style_for_logo = Style.new(
  module_shape: :rounded,
  module_radius: 0.3,
  finder: %{outer: "#4B275F", inner: "#FFFFFF", eye: "#9B59B6"}
)
Qiroex.save_svg("https://elixir-lang.org", "#{out}/logo_styled.svg",
  module_size: 8, quiet_zone: 2, level: :h,
  style: style_for_logo, logo: logo)
IO.puts("  ✓ logo_styled.svg")

# ── 12. WiFi payload ─────────────────────────────────────────────
{:ok, wifi_data} = Qiroex.Payload.WiFi.encode(ssid: "CoffeeShop", password: "latte2024", security: "WPA")
Qiroex.save_svg(wifi_data, "#{out}/wifi.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#2C3E50")
IO.puts("  ✓ wifi.svg")

# ── 13. vCard payload ────────────────────────────────────────────
{:ok, vcard_data} = Qiroex.Payload.VCard.encode(
  first_name: "Jane", last_name: "Doe",
  phone: "+1-555-0199", email: "jane@example.com",
  org: "Acme Corp", title: "Engineer"
)
style_vcard = Style.new(module_shape: :rounded, module_radius: 0.3,
  finder: %{outer: "#0984E3", inner: "#FFFFFF", eye: "#6C5CE7"})
Qiroex.save_svg(vcard_data, "#{out}/vcard.svg",
  module_size: 6, quiet_zone: 2, style: style_vcard)
IO.puts("  ✓ vcard.svg")

# ── 14. PNG example ──────────────────────────────────────────────
Qiroex.save_png("https://elixir-lang.org", "#{out}/basic.png",
  module_size: 10, quiet_zone: 3)
IO.puts("  ✓ basic.png")

# ── 15. PNG styled with finder colors ────────────────────────────
style_png = Style.new(finder: %{outer: "#E63946", inner: "#F1FAEE", eye: "#1D3557"})
Qiroex.save_png("https://elixir-lang.org", "#{out}/styled.png",
  module_size: 10, quiet_zone: 3, style: style_png)
IO.puts("  ✓ styled.png")

IO.puts("\nDone! #{length(File.ls!(out))} files generated in #{out}/")
