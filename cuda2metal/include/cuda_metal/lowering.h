#ifndef CM_LOWERING_H
#define CM_LOWERING_H

#pragma once
#include "ast.h"
#include "ir.h"

typedef struct cm_lowering_context {
    cm_ir_module_t* module;
    cm_ir_function_t* current_function;
    cm_ir_block_t* current_block;
    cm_error_t* error;
    struct cm_symbol_table* symbol_table;
    struct cm_type_map* type_map;
    cm_ir_address_space_t address_space_map[CM_ADDRESS_SPACE_COUNT];
    uint32_t grid[3];
    uint32_t block[3];
    uint32_t shared_mem;
} cm_lowering_context_t;

cm_lowering_context_t* cm_lowering_context_create(cm_ir_module_t* module);
void cm_lowering_context_destroy(cm_lowering_context_t* ctx);

bool cm_lower_translation_unit(cm_lowering_context_t* ctx, cm_node_t* tu);
bool cm_lower_kernel(cm_lowering_context_t* ctx, cm_node_t* kernel);
bool cm_lower_function(cm_lowering_context_t* ctx, cm_node_t* func);
bool cm_lower_statement(cm_lowering_context_t* ctx, cm_node_t* stmt);
bool cm_lower_expression(cm_lowering_context_t* ctx, cm_node_t* expr, cm_ir_value_t** result);

bool cm_lower_cuda_intrinsics(cm_lowering_context_t* ctx);
bool cm_lower_thread_hierarchy(cm_lowering_context_t* ctx);
bool cm_lower_memory_spaces(cm_lowering_context_t* ctx);
bool cm_lower_synchronization(cm_lowering_context_t* ctx);
bool cm_lower_atomics(cm_lowering_context_t* ctx);

bool cm_lower_to_metal(cm_lowering_context_t* ctx, cm_ir_module_t* ir_module);
bool cm_lower_simd_groups(cm_lowering_context_t* ctx);
bool cm_lower_resource_bindings(cm_lowering_context_t* ctx);

#endif // CM_LOWERING_H
