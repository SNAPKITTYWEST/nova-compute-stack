# CUDA-to-Metal Translation Stack — Production Architecture

## Engineering Principle & Invariant

The system treats CUDA and Metal as two distinct GPU execution models connected through a formally defined translation boundary:

```
CUDA semantics
      ↓
normalized GPU semantics (hardware-neutral IR)
      ↓
verified lowering (pass pipeline)
      ↓
Metal semantics (MSL emission)
```

**Primary invariant:** If the compiler accepts a CUDA construct, the generated Metal program must preserve the supported observable computational semantics. If equivalence cannot be established, compilation must fail explicitly with a diagnostic. No silent approximation, no regex rewriting, no emulation of NVIDIA hardware.

This is not a source-to-source converter. It is a compiler with a typed AST, SSA-based IR, and independent lowering passes.

---

## Repository Structure

```
cuda2metal/
├── CMakeLists.txt
├── LICENSE
├── compiler/
│   ├── lexer/          lexer.h · lexer.c · token.h
│   ├── parser/         parser.h · parser.c · cuda_ext.h
│   ├── ast/            ast.h · ast.c · type.h
│   ├── semantic/       sema.h · sema.c · addrspace_infer.c
│   ├── ir/             ir.h · ir_builder.c · ssa.c · ir_verify.c
│   ├── passes/         pass_manager.h · const_prop.c · dce.c
│   │                   barrier_analysis.c · atomic_legalize.c
│   │                   subgroup_lower.c · addrspace_lower.c
│   │                   thread_index_lower.c · metal_type_lower.c
│   └── metal_backend/  msl_emitter.h · msl_emitter.c
│                       abi_gen.c · msl_runtime.metal
├── runtime/
│   ├── device.h/.mm
│   ├── memory.h/.mm
│   ├── dispatch.h/.mm
│   ├── synchronization.h/.mm
│   └── pipeline_cache.h/.mm
├── stdlib/
│   ├── math.metal
│   ├── atomics.metal
│   ├── subgroup.metal
│   ├── memory.metal
│   └── synchronization.metal
├── tests/
└── examples/
    ├── vector_add/
    ├── matmul/
    ├── reduction/
    ├── softmax/
    └── attention/
```

---

## Pass Pipeline

```
AST → IR Builder
  → SSA Construction (mem2reg + phi insertion)
  → Constant Propagation
  → Dead Code Elimination
  → Address-Space Inference (Generic → concrete)
  → Memory Legalization
  → Intrinsic Normalization
  → Thread-Index Lowering
  → Barrier Analysis (classify scope: threadgroup vs. device)
  → Atomic Legalization
  → Subgroup Lowering (WarpOp → SubgroupOp → MSL simd_*)
  → Metal Type Legalization
  → MSL Emission
  → ABI Generation (kernel.json)
  → Validation
```

---

## Semantic Mapping: CUDA → MSL

| CUDA | MSL | Notes |
|------|-----|-------|
| `__global__` | `kernel` | Entry-point qualifier |
| `threadIdx.x/y/z` | `thread_position_in_threadgroup.x/y/z` | |
| `blockIdx.x/y/z` | `threadgroup_position_in_grid.x/y/z` | |
| `blockDim.x/y/z` | `threads_per_threadgroup.x/y/z` | |
| `__shared__` | `threadgroup` address space | |
| `__constant__` | `constant` address space | |
| `__syncthreads()` | `threadgroup_barrier(mem_flags::mem_threadgroup)` | See barrier notes |
| `atomicAdd` | `atomic_fetch_add_explicit` | |
| `__shfl_sync` | `simd_shuffle` | Mask must be all-active |

---

## Critical Design Decisions

### Barrier Semantics

`__syncthreads()` → `threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device)`

The `mem_threadgroup` flag is mandatory. `mem_flags::mem_none` would silently weaken memory ordering. The `barrier_analysis` pass determines the correct flags automatically.

### float3 / packed_float3

CUDA `float3` is 12 bytes (4-byte aligned). Metal native `float3` is 16 bytes (16-byte aligned). The compiler uses `packed_float3` to preserve ABI compatibility and emits diagnostic `C2M-090`.

### SIMD-Group Mask Semantics

CUDA `__shfl_sync(mask, val, lane)` drops the mask only if the compiler can prove the mask is `0xFFFFFFFF`. Otherwise → reject with `C2M-041`.

---

## Unsupported Feature Matrix

| CUDA Feature | Status | Diagnostic |
|---|---|---|
| `__shfl_sync` with non-all-active mask | Rejected | C2M-041 |
| `atomicAdd` on `double` | Rejected | C2M-070 |
| `atomicAdd` on `half` (Metal < 3.2) | CAS emulation | C2M-060 warning |
| Dynamic parallelism | Rejected | C2M-080 |
| `__constant__` > 64 KB | Rejected | C2M-081 |

---

## Example: Shared-Memory Matmul Translation

### Input CUDA
```cuda
__global__ void matmul(const float *A, const float *B, float *C, int M, int N, int K) {
    __shared__ float As[16][16];
    __shared__ float Bs[16][16];
    // ... tiled computation + __syncthreads()
}
```

### Generated MSL
```metal
#include <metal_stdlib>
using namespace metal;

kernel void matmul(
    device const float* A [[buffer(0)]],
    device const float* B [[buffer(1)]],
    device float* C [[buffer(2)]],
    uint3 tid [[thread_position_in_threadgroup]],
    uint3 group [[threadgroup_position_in_grid]]
) {
    threadgroup float As[16][16];
    threadgroup float Bs[16][16];
    // ...
    threadgroup_barrier(mem_flags::mem_threadgroup); // NOT mem_none
    // ...
}
```
