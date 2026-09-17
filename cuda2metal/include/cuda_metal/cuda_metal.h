/**
 * CUDA-METAL: Production-Grade CUDA to Metal Shading Language Translation Stack
 *
 * PIPELINE:
 *   CUDA Source -> Lexer/Parser -> CUDA AST -> Semantic Analysis -> GPU IR ->
 *   CUDA Lowering -> Metal Lowering -> MSL AST -> MSL Codegen -> .metallib ->
 *   Metal Runtime -> Apple GPU
 *
 * DESIGN PRINCIPLES:
 *   - Deterministic translation (same input -> same output)
 *   - Local-first (no external services)
 *   - Fail-closed (reject unsupported constructs explicitly)
 *   - Hardware-neutral IR
 *   - Preserve generated MSL as inspectable artifact
 *   - Correctness before compatibility breadth
 *
 * LICENSE: MIT
 * VERSION: 1.0.0
 */

#ifndef CUDA_METAL_H
#define CUDA_METAL_H

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_MAC
#define CM_HAS_METAL 1
#endif
#endif

struct cm_module;
struct cm_kernel;
struct cm_device;
struct cm_buffer;
struct cm_error;

typedef struct cm_module cm_module_t;
typedef struct cm_kernel cm_kernel_t;
typedef struct cm_device cm_device_t;
typedef struct cm_buffer cm_buffer_t;
typedef struct cm_error cm_error_t;

typedef enum {
    CM_SUCCESS = 0,
    CM_ERROR_PARSE,
    CM_ERROR_SEMANTIC,
    CM_ERROR_IR,
    CM_ERROR_LOWERING,
    CM_ERROR_CODEGEN,
    CM_ERROR_COMPILE,
    CM_ERROR_RUNTIME,
    CM_ERROR_UNSUPPORTED,
    CM_ERROR_MEMORY,
    CM_ERROR_COUNT
} cm_error_code_t;

typedef struct cm_error {
    cm_error_code_t code;
    const char* message;
    const char* file;
    uint32_t line;
    uint32_t column;
    const char* stage;
    const char* construct;
    const char* reason;
    const char* action;
} cm_error_t;

cm_error_t* cm_error_create(cm_error_code_t code, const char* message, ...);
void cm_error_destroy(cm_error_t* error);
const char* cm_error_to_string(cm_error_t* error);

typedef struct {
    const char* cuda_source;
    size_t source_length;
    const char* source_file;
    const char* output_file;
    const char* metallib_file;
    bool verbose;
    bool keep_intermediates;
    bool optimize;
    uint32_t optimization_level;
} cm_compile_options_t;

typedef struct {
    cm_module_t* module;
    cm_error_t* error;
    const char* msl_source;
    size_t msl_length;
    const char* metallib_path;
    bool success;
} cm_compile_result_t;

cm_compile_result_t* cm_compile(cm_compile_options_t* options);
void cm_compile_result_destroy(cm_compile_result_t* result);

cm_module_t* cm_module_create(const char* name);
void cm_module_destroy(cm_module_t* module);

cm_kernel_t* cm_module_get_kernel(cm_module_t* module, const char* name);
const char* cm_kernel_get_name(cm_kernel_t* kernel);

typedef struct {
    uint32_t grid[3];
    uint32_t block[3];
    uint32_t shared_mem;
    uint32_t stream;
} cm_launch_config_t;

cm_device_t* cm_device_create(uint32_t index);
void cm_device_destroy(cm_device_t* device);
const char* cm_device_get_name(cm_device_t* device);
bool cm_device_is_unified_memory(cm_device_t* device);

cm_buffer_t* cm_buffer_create(cm_device_t* device, size_t size, bool is_device);
void cm_buffer_destroy(cm_buffer_t* buffer);
void* cm_buffer_get_host_ptr(cm_buffer_t* buffer);
void* cm_buffer_get_device_ptr(cm_buffer_t* buffer);
size_t cm_buffer_get_size(cm_buffer_t* buffer);

bool cm_buffer_copy_host_to_device(cm_buffer_t* buffer, const void* host_ptr, size_t size);
bool cm_buffer_copy_device_to_host(cm_buffer_t* buffer, void* host_ptr, size_t size);
bool cm_buffer_copy_device_to_device(cm_buffer_t* dst, cm_buffer_t* src, size_t size);

bool cm_kernel_launch(
    cm_kernel_t* kernel,
    cm_device_t* device,
    cm_launch_config_t* config,
    cm_buffer_t** args,
    uint32_t num_args,
    cm_error_t** error
);

bool cm_device_synchronize(cm_device_t* device, cm_error_t** error);

int cm_main(int argc, char** argv);

#endif // CUDA_METAL_H
