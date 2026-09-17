#ifndef CM_AST_H
#define CM_AST_H

#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct cm_source_location {
    const char* file;
    uint32_t line, column, offset;
} cm_source_location_t;

static inline cm_source_location_t cm_loc(uint32_t line, uint32_t col) {
    return (cm_source_location_t){NULL, line, col, 0};
}

typedef enum {
    CM_TOK_EOF, CM_TOK_IDENT, CM_TOK_INT, CM_TOK_FLOAT, CM_TOK_STR,
    CM_TOK_GLOBAL, CM_TOK_DEVICE, CM_TOK_SHARED, CM_TOK_CONSTANT,
    CM_TOK_KERNEL, CM_TOK_IF, CM_TOK_ELSE, CM_TOK_FOR, CM_TOK_RETURN,
    CM_TOK_THREAD_IDX, CM_TOK_BLOCK_IDX, CM_TOK_BLOCK_DIM, CM_TOK_GRID_DIM,
    CM_TOK_SYNC_THREADS, CM_TOK_ATOMIC,
    CM_TOK_PLUS, CM_TOK_MINUS, CM_TOK_STAR, CM_TOK_SLASH,
    CM_TOK_LPAREN, CM_TOK_RPAREN, CM_TOK_LBRACE, CM_TOK_RBRACE,
    CM_TOK_COMMA, CM_TOK_SEMI, CM_TOK_COLON,
    CM_TOK_TYPE_VOID, CM_TOK_TYPE_BOOL, CM_TOK_TYPE_INT,
    CM_TOK_TYPE_FLOAT, CM_TOK_TYPE_HALF
} cm_token_type_t;

typedef enum {
    CM_NODE_TRANSLATION_UNIT, CM_NODE_KERNEL, CM_NODE_FUNC, CM_NODE_VAR,
    CM_NODE_PARAM, CM_NODE_STRUCT, CM_NODE_TYPE, CM_NODE_COMPOUND,
    CM_NODE_IF, CM_NODE_FOR, CM_NODE_RETURN, CM_NODE_BINARY, CM_NODE_UNARY,
    CM_NODE_CALL, CM_NODE_MEMBER, CM_NODE_SUBSCRIPT, CM_NODE_IDENT,
    CM_NODE_INT_LIT, CM_NODE_FLOAT_LIT, CM_NODE_BOOL_LIT, CM_NODE_CAST,
    CM_NODE_SYNC_THREADS, CM_NODE_THREAD_IDX, CM_NODE_BLOCK_IDX,
    CM_NODE_BLOCK_DIM, CM_NODE_GRID_DIM
} cm_node_type_t;

typedef enum {
    CM_AS_PRIVATE, CM_AS_THREADGROUP, CM_AS_DEVICE, CM_AS_CONSTANT,
    CM_ADDRESS_SPACE_COUNT
} cm_address_space_t;

typedef struct cm_node cm_node_t;
typedef struct cm_type cm_type_t;

struct cm_node {
    cm_node_type_t type;
    cm_source_location_t loc;
    cm_node_t* parent;
    cm_type_t* resolved_type;
    union {
        struct { cm_node_t** decls; uint32_t count; } translation_unit;
        struct { char* name; cm_node_t* ret; cm_node_t** params; uint32_t pcount; cm_node_t* body; uint32_t grid[3]; uint32_t block[3]; } kernel;
        struct { char* name; cm_node_t* type; cm_node_t* init; } var;
        struct { char* name; cm_node_t* type; } param;
        struct { char* name; cm_node_t** fields; uint32_t fcount; } struct_decl;
        struct { cm_node_t** stmts; uint32_t count; } compound;
        struct { cm_node_t* cond; cm_node_t* then_b; cm_node_t* else_b; } if_node;
        struct { cm_node_t* init; cm_node_t* cond; cm_node_t* incr; cm_node_t* body; } for_node;
        struct { cm_node_t* expr; } return_node;
        struct { cm_node_t* left; cm_node_t* right; cm_token_type_t op; } binary;
        struct { cm_node_t* operand; cm_token_type_t op; } unary;
        struct { cm_node_t* callee; cm_node_t** args; uint32_t acount; } call;
        struct { cm_node_t* obj; char* member; bool arrow; } member;
        struct { cm_node_t* arr; cm_node_t* idx; } subscript;
        struct { char* name; } ident;
        struct { int64_t value; } int_lit;
        struct { double value; } float_lit;
        struct { bool value; } bool_lit;
        struct { cm_node_t* type; cm_node_t* expr; } cast;
        struct { uint32_t dim; } thread_idx;
        struct { uint32_t dim; } block_idx;
        struct { uint32_t dim; } block_dim;
        struct { uint32_t dim; } grid_dim;
    };
};

typedef enum {
    CM_TYPE_VOID, CM_TYPE_BASIC, CM_TYPE_PTR, CM_TYPE_ARRAY,
    CM_TYPE_VECTOR, CM_TYPE_STRUCT
} cm_type_kind_t;

struct cm_type {
    cm_type_kind_t kind;
    union {
        struct { uint32_t bits; bool is_unsigned; } basic;
        struct { cm_type_t* elem; cm_address_space_t as; } ptr;
        struct { cm_type_t* elem; uint64_t size; } array;
        struct { cm_type_t* elem; uint32_t size; } vector;
        struct { char* name; cm_node_t** fields; uint32_t fcount; } struct_type;
    };
};

cm_node_t* cm_node_create(cm_node_type_t type, cm_source_location_t loc);
void cm_node_destroy(cm_node_t* node);
cm_type_t* cm_type_create_basic(uint32_t bits, bool is_unsigned);
cm_type_t* cm_type_create_ptr(cm_type_t* elem, cm_address_space_t as);
void cm_type_destroy(cm_type_t* type);

#endif // CM_AST_H
