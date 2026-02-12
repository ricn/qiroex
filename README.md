# Qiroex

A pure Elixir QR code generation library with zero external dependencies. Supports all 40 QR versions, 4 encoding modes (numeric, alphanumeric, byte, kanji), and 4 error correction levels.

## Installation

Add `qiroex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:qiroex, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic encoding

```elixir
# Encode data into a QR code struct
{:ok, qr} = Qiroex.encode("Hello, World!")

# Inspect the selected version, EC level, and mask
qr.version   #=> 1
qr.ec_level  #=> :m
qr.mask      #=> 0..7

# Bang variant raises on error
qr = Qiroex.encode!("Hello, World!")
```

### Error correction levels

```elixir
# :l (7%), :m (15%, default), :q (25%), :h (30%)
{:ok, qr} = Qiroex.encode("Hello", level: :h)
qr.ec_level  #=> :h
```

### Forcing a version

```elixir
# Force a specific QR version (1-40)
{:ok, qr} = Qiroex.encode("Hello", version: 5, level: :m)
qr.version  #=> 5
```

### Getting the matrix as a 2D list

```elixir
# Returns a 2D list of 0s (light) and 1s (dark), including a quiet zone
{:ok, matrix} = Qiroex.to_matrix("Hello, World!")

# Or use the bang variant
matrix = Qiroex.to_matrix!("Hello, World!", level: :q)

# Each row is a list of 0/1 integers
Enum.count(matrix)      #=> matrix size + 8 (4-module quiet zone on each side)
Enum.count(hd(matrix))  #=> same

# Access from a QR struct directly (margin = quiet zone modules per side)
{:ok, qr} = Qiroex.encode("Hello")
rows = Qiroex.QR.to_matrix(qr)       # default margin: 4
rows = Qiroex.QR.to_matrix(qr, 2)    # custom margin: 2
```

### SVG output

```elixir
# Generate an SVG string
{:ok, svg} = Qiroex.to_svg("https://example.com")

# Bang variant
svg = Qiroex.to_svg!("https://example.com")

# Write directly to a file
:ok = Qiroex.save_svg("https://example.com", "qr.svg")

# Customize appearance
svg = Qiroex.to_svg!("Hello",
  module_size: 5,
  quiet_zone: 2,
  dark_color: "#1a1a2e",
  light_color: "#e0e0e0"
)
```

### PNG output

```elixir
# Generate a PNG binary
{:ok, png} = Qiroex.to_png("https://example.com")

# Bang variant
png = Qiroex.to_png!("https://example.com")

# Write directly to a file
:ok = Qiroex.save_png("https://example.com", "qr.png")

# Customize appearance (colors are {r, g, b} tuples)
png = Qiroex.to_png!("Hello",
  module_size: 20,
  quiet_zone: 2,
  dark_color: {0, 0, 128},
  light_color: {255, 255, 240}
)
```

### Terminal output

```elixir
# Print directly to the terminal (compact mode, 2 rows per line)
Qiroex.print("https://example.com")

# Get as a string instead
{:ok, output} = Qiroex.to_terminal("Hello")

# Simple mode (1 row per line, wider output)
Qiroex.print("Hello", compact: false)

# Custom quiet zone
Qiroex.print("Hello", quiet_zone: 1)
```

### Encoding modes

The library auto-detects the most efficient encoding mode:

```elixir
# Numeric (0-9 only) — most compact
{:ok, qr} = Qiroex.encode("0123456789")
qr.mode  #=> :numeric

# Alphanumeric (0-9, A-Z, space, $%*+-./:)
{:ok, qr} = Qiroex.encode("HELLO WORLD")
qr.mode  #=> :alphanumeric

# Byte (any UTF-8 / Latin-1 text)
{:ok, qr} = Qiroex.encode("hello world")
qr.mode  #=> :byte

# Force a specific mode
{:ok, qr} = Qiroex.encode("123", mode: :byte)
qr.mode  #=> :byte
```

### Error handling

```elixir
# Data too large for requested EC level
{:error, reason} = Qiroex.encode(String.duplicate("A", 5000), level: :h)

# Empty data
{:error, "Data cannot be empty"} = Qiroex.encode("")
```

## Roadmap

- [x] Core QR engine (all 40 versions, 4 modes, 4 EC levels, masking)
- [x] SVG renderer
- [x] PNG renderer
- [x] Terminal renderer
- [ ] Payload builders (WiFi, vCard, URL, email, SMS, geo, etc.)
- [ ] Visual styling (colors, shapes, gradients)
- [ ] SVG logo embedding

