#!/usr/bin/env bash
set -euo pipefail

sdk_name="${1:-iphoneos}"
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shader_dir="$project_dir/packages/live2d-native-metal/vendor/Cubism/Framework/src/Rendering/Metal/Shaders"
sample_shader_dir="$project_dir/packages/live2d-native-metal/vendor/Cubism/Samples/Metal/Demo/proj.ios.cmake/src/Shaders"
resource_dir="$project_dir/packages/live2d-native-metal/Resources"
output_dir="$resource_dir/FrameworkMetallibs"
intermediate_dir="$resource_dir/.shader-intermediates"

rm -rf "$output_dir" "$intermediate_dir"
mkdir -p "$output_dir" "$intermediate_dir" "$resource_dir/Shaders"
cp "$sample_shader_dir/SpriteEffect.metal" "$resource_dir/Shaders/SpriteEffect.metal.txt"

compile_shader() {
  local source_name="$1"
  local output_name="$2"
  shift 2
  local air_file="$intermediate_dir/$output_name.air"

  xcrun --sdk "$sdk_name" metal -I "$shader_dir" "$@" -c "$shader_dir/$source_name.metal" -o "$air_file"
  xcrun --sdk "$sdk_name" metallib -o "$output_dir/$output_name.metallib" "$air_file"
}

compile_shader MetalShaders MetalShaders
compile_shader VertShaderSrcBlend VertShaderSrcBlend
compile_shader VertShaderSrcMaskedBlend VertShaderSrcMaskedBlend

color_modes=(Normal Add AddGlow Darken Multiply ColorBurn LinearBurn Lighten Screen ColorDodge Overlay SoftLight HardLight LinearLight Hue Color)
alpha_modes=(Over Atop Out ConjointOver DisjointOver)
fragment_sources=(FragShaderSrcBlend FragShaderSrcMaskBlend FragShaderSrcMaskInvertedBlend FragShaderSrcPremultipliedAlphaBlend FragShaderSrcMaskPremultipliedAlphaBlend FragShaderSrcMaskInvertedPremultipliedAlphaBlend)

for color_index in "${!color_modes[@]}"; do
  for alpha_index in "${!alpha_modes[@]}"; do
    if [[ "$color_index" == 0 && "$alpha_index" == 0 ]]; then
      continue
    fi
    for source_name in "${fragment_sources[@]}"; do
      compile_shader "$source_name" "${source_name}${color_modes[$color_index]}${alpha_modes[$alpha_index]}" \
        "-DCSM_COLOR_BLEND_MODE=$color_index" "-DCSM_ALPHA_BLEND_MODE=$alpha_index"
    done
  done
done

rm -rf "$intermediate_dir"
