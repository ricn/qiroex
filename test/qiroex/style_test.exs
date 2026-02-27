defmodule Qiroex.StyleTest do
  use ExUnit.Case, async: true

  alias Qiroex.Style

  describe "new/1" do
    test "creates default style" do
      style = Style.new()
      assert style.module_shape == :square
      assert style.module_radius == 0.5
      assert style.finder == nil
      assert style.gradient == nil
    end

    test "accepts module_shape" do
      for shape <- [:square, :rounded, :circle, :diamond, :leaf, :shield] do
        style = Style.new(module_shape: shape)
        assert style.module_shape == shape
      end
    end

    test "accepts module_radius" do
      style = Style.new(module_radius: 0.3)
      assert style.module_radius == 0.3
    end

    test "accepts finder map" do
      finder = %{outer: "#ff0000", inner: "#00ff00", eye: "#0000ff"}
      style = Style.new(finder: finder)
      assert style.finder == finder
    end

    test "accepts partial finder map" do
      finder = %{eye: "#e74c3c"}
      style = Style.new(finder: finder)
      assert style.finder == finder
    end

    test "accepts linear gradient" do
      gradient = %{type: :linear, start_color: "#000", end_color: "#3498db"}
      style = Style.new(gradient: gradient)
      assert style.gradient == gradient
    end

    test "accepts radial gradient" do
      gradient = %{type: :radial, start_color: "#000", end_color: "#fff"}
      style = Style.new(gradient: gradient)
      assert style.gradient.type == :radial
    end

    test "accepts gradient with angle" do
      gradient = %{type: :linear, start_color: "#000", end_color: "#fff", angle: 45}
      style = Style.new(gradient: gradient)
      assert style.gradient.angle == 45
    end

    test "rejects invalid shape" do
      assert_raise ArgumentError, ~r/invalid module_shape/, fn ->
        Style.new(module_shape: :star)
      end
    end

    test "rejects invalid radius" do
      assert_raise ArgumentError, ~r/invalid module_radius/, fn ->
        Style.new(module_radius: 1.0)
      end

      assert_raise ArgumentError, ~r/invalid module_radius/, fn ->
        Style.new(module_radius: -0.1)
      end
    end

    test "rejects invalid finder keys" do
      assert_raise ArgumentError, ~r/invalid finder keys/, fn ->
        Style.new(finder: %{border: "#fff"})
      end
    end

    test "rejects non-map finder" do
      assert_raise ArgumentError, ~r/finder must be a map/, fn ->
        Style.new(finder: "red")
      end
    end

    test "rejects invalid gradient type" do
      assert_raise ArgumentError, ~r/invalid gradient type/, fn ->
        Style.new(gradient: %{type: :conic, start_color: "#000", end_color: "#fff"})
      end
    end

    test "rejects gradient without colors" do
      assert_raise ArgumentError, ~r/requires :start_color/, fn ->
        Style.new(gradient: %{type: :linear})
      end
    end
  end

  describe "default?/1" do
    test "nil is default" do
      assert Style.default?(nil)
    end

    test "default struct is default" do
      assert Style.default?(Style.new())
    end

    test "custom shape is not default" do
      refute Style.default?(Style.new(module_shape: :circle))
    end

    test "finder styling is not default" do
      refute Style.default?(Style.new(finder: %{eye: "#red"}))
    end

    test "gradient is not default" do
      refute Style.default?(
               Style.new(gradient: %{type: :linear, start_color: "#000", end_color: "#fff"})
             )
    end
  end

  describe "custom_finder?/1" do
    test "nil has no custom finder" do
      refute Style.custom_finder?(nil)
    end

    test "no finder set" do
      refute Style.custom_finder?(Style.new())
    end

    test "finder set" do
      assert Style.custom_finder?(Style.new(finder: %{eye: "#ff0000"}))
    end
  end

  describe "finder_color/3" do
    test "returns default when style is nil" do
      assert Style.finder_color(nil, :eye, "#000") == "#000"
    end

    test "returns default when no finder set" do
      style = Style.new()
      assert Style.finder_color(style, :eye, "#000") == "#000"
    end

    test "returns configured color" do
      style = Style.new(finder: %{eye: "#ff0000", outer: "#00ff00"})
      assert Style.finder_color(style, :eye, "#000") == "#ff0000"
      assert Style.finder_color(style, :outer, "#000") == "#00ff00"
    end

    test "returns default for unconfigured layer" do
      style = Style.new(finder: %{eye: "#ff0000"})
      assert Style.finder_color(style, :outer, "#000") == "#000"
    end
  end

  describe "finder shape keys" do
    test "accepts finder map with shape keys" do
      finder = %{outer_shape: :circle, inner_shape: :rounded, eye_shape: :diamond}
      style = Style.new(finder: finder)
      assert style.finder == finder
    end

    test "accepts all valid finder shapes" do
      for shape <- [:square, :rounded, :circle, :diamond, :leaf, :shield] do
        style = Style.new(finder: %{outer_shape: shape})
        assert style.finder.outer_shape == shape
      end
    end

    test "accepts mixed color and shape keys" do
      finder = %{outer: "#ff0000", outer_shape: :leaf, eye: "#0000ff", eye_shape: :circle}
      style = Style.new(finder: finder)
      assert style.finder == finder
    end

    test "rejects invalid finder shape value" do
      assert_raise ArgumentError, ~r/invalid finder shape/, fn ->
        Style.new(finder: %{outer_shape: :star})
      end
    end

    test "rejects invalid finder shape for inner" do
      assert_raise ArgumentError, ~r/invalid finder shape/, fn ->
        Style.new(finder: %{inner_shape: :hexagon})
      end
    end

    test "rejects invalid finder shape for eye" do
      assert_raise ArgumentError, ~r/invalid finder shape/, fn ->
        Style.new(finder: %{eye_shape: :triangle})
      end
    end
  end

  describe "custom_finder_shapes?/1" do
    test "nil has no custom finder shapes" do
      refute Style.custom_finder_shapes?(nil)
    end

    test "no finder set" do
      refute Style.custom_finder_shapes?(Style.new())
    end

    test "finder with colors only has no custom shapes" do
      refute Style.custom_finder_shapes?(Style.new(finder: %{eye: "#ff0000"}))
    end

    test "finder with outer_shape" do
      assert Style.custom_finder_shapes?(Style.new(finder: %{outer_shape: :circle}))
    end

    test "finder with inner_shape" do
      assert Style.custom_finder_shapes?(Style.new(finder: %{inner_shape: :rounded}))
    end

    test "finder with eye_shape" do
      assert Style.custom_finder_shapes?(Style.new(finder: %{eye_shape: :diamond}))
    end

    test "finder with mixed colors and shapes" do
      assert Style.custom_finder_shapes?(
               Style.new(finder: %{outer: "#ff0000", eye_shape: :leaf})
             )
    end
  end

  describe "finder_shape/3" do
    test "returns default when style is nil" do
      assert Style.finder_shape(nil, :outer, :square) == :square
    end

    test "returns default when no finder set" do
      style = Style.new()
      assert Style.finder_shape(style, :outer, :square) == :square
    end

    test "returns configured shape" do
      style = Style.new(finder: %{outer_shape: :circle, eye_shape: :diamond})
      assert Style.finder_shape(style, :outer, :square) == :circle
      assert Style.finder_shape(style, :eye, :square) == :diamond
    end

    test "returns default for unconfigured layer" do
      style = Style.new(finder: %{outer_shape: :circle})
      assert Style.finder_shape(style, :inner, :square) == :square
      assert Style.finder_shape(style, :eye, :square) == :square
    end

    test "returns each shape type correctly" do
      for shape <- [:square, :rounded, :circle, :diamond, :leaf, :shield] do
        style = Style.new(finder: %{outer_shape: shape})
        assert Style.finder_shape(style, :outer, :square) == shape
      end
    end
  end
end
