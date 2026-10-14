# AVX2-optimized llama.cpp for CPUs without a usable GPU backend.
#
# nixpkgs builds llama.cpp with GGML_NATIVE=OFF (for determinism) and only
# applies per-CPU ISA flags on the GGML_CPU_ALL_VARIANTS path, so a plain
# `pkgs.llama-cpp` is baseline SSE2 with no AVX/FMA — on an older CPU like
# argon's Ryzen 5 3400G that roughly halves throughput. This overlay re-enables
# the flags the CPU actually supports (4B tg: 2.4 -> 7.4 tok/s in the bake-off),
# mirroring the hand-built /root/llama-cpp-avx2.nix that was used to measure it.
#
# Only import where the machine has AVX2/FMA/F16C/BMI2 (Haswell+, Zen+).

{ ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      llama-cpp-avx2 = prev.llama-cpp.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DGGML_SSE42=ON"
          "-DGGML_AVX=ON"
          "-DGGML_AVX2=ON"
          "-DGGML_FMA=ON"
          "-DGGML_F16C=ON"
          "-DGGML_BMI2=ON"
        ];
        NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "")
          + " -mavx2 -mfma -mf16c -mbmi2 -msse4.2"
          + " -DGGML_AVX2 -DGGML_FMA -DGGML_F16C -DGGML_BMI2 -DGGML_AVX -DGGML_SSE42";
      });
    })
  ];
}
