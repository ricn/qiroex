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

# ── 14. URL payload ──────────────────────────────────────────────
{:ok, url_data} = Qiroex.Payload.URL.encode(url: "https://elixir-lang.org")
Qiroex.save_svg(url_data, "#{out}/url.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#2980B9")
IO.puts("  ✓ url.svg")

# ── 15. Email payload ────────────────────────────────────────────
{:ok, email_data} = Qiroex.Payload.Email.encode(
  to: "hello@example.com", subject: "Hi there!", body: "Nice to meet you."
)
Qiroex.save_svg(email_data, "#{out}/email.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#E74C3C")
IO.puts("  ✓ email.svg")

# ── 16. SMS payload ──────────────────────────────────────────────
{:ok, sms_data} = Qiroex.Payload.SMS.encode(number: "+1-555-0123", message: "Hello from Qiroex!")
Qiroex.save_svg(sms_data, "#{out}/sms.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#27AE60")
IO.puts("  ✓ sms.svg")

# ── 17. Phone payload ────────────────────────────────────────────
{:ok, phone_data} = Qiroex.Payload.Phone.encode(number: "+1-555-0199")
Qiroex.save_svg(phone_data, "#{out}/phone.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#34495E")
IO.puts("  ✓ phone.svg")

# ── 18. Geo payload ──────────────────────────────────────────────
{:ok, geo_data} = Qiroex.Payload.Geo.encode(
  latitude: 48.8566, longitude: 2.3522, query: "Eiffel Tower"
)
Qiroex.save_svg(geo_data, "#{out}/geo.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#16A085")
IO.puts("  ✓ geo.svg")

# ── 19. vEvent payload ───────────────────────────────────────────
{:ok, vevent_data} = Qiroex.Payload.VEvent.encode(
  summary: "Team Standup",
  start: ~U[2026-03-01 09:00:00Z],
  end: ~U[2026-03-01 09:30:00Z],
  location: "Conference Room A"
)
Qiroex.save_svg(vevent_data, "#{out}/vevent.svg",
  module_size: 6, quiet_zone: 2, dark_color: "#E67E22")
IO.puts("  ✓ vevent.svg")

# ── 20. MeCard payload ───────────────────────────────────────────
{:ok, mecard_data} = Qiroex.Payload.MeCard.encode(
  name: "Doe,Jane", phone: "+1-555-0199", email: "jane@example.com"
)
Qiroex.save_svg(mecard_data, "#{out}/mecard.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#8E44AD")
IO.puts("  ✓ mecard.svg")

# ── 21. Bitcoin payload ──────────────────────────────────────────
{:ok, bitcoin_data} = Qiroex.Payload.Bitcoin.encode(
  address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
  amount: 0.001, label: "Donation"
)
Qiroex.save_svg(bitcoin_data, "#{out}/bitcoin.svg",
  module_size: 6, quiet_zone: 2, dark_color: "#F7931A")
IO.puts("  ✓ bitcoin.svg")

# ── 22. WhatsApp payload ─────────────────────────────────────────
{:ok, whatsapp_data} = Qiroex.Payload.WhatsApp.encode(
  number: "+1234567890", message: "Hello from Qiroex!"
)
style_whatsapp = Style.new(module_shape: :rounded, module_radius: 0.3)
Qiroex.save_svg(whatsapp_data, "#{out}/whatsapp.svg",
  module_size: 8, quiet_zone: 2, dark_color: "#25D366", style: style_whatsapp)
IO.puts("  ✓ whatsapp.svg")

# ── 23. PNG example ──────────────────────────────────────────────
Qiroex.save_png("https://elixir-lang.org", "#{out}/basic.png",
  module_size: 10, quiet_zone: 3)
IO.puts("  ✓ basic.png")

# ── 24. PNG styled with finder colors ────────────────────────────
style_png = Style.new(finder: %{outer: "#E63946", inner: "#F1FAEE", eye: "#1D3557"})
Qiroex.save_png("https://elixir-lang.org", "#{out}/styled.png",
  module_size: 10, quiet_zone: 3, style: style_png)
IO.puts("  ✓ styled.png")

IO.puts("\nDone! #{length(File.ls!(out))} files generated in #{out}/")
