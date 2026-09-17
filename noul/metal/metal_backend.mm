// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT
//
// Metal backend using metal-cpp (header-only C++ interface).
// Compiled with: clang++ -std=c++17 -x objective-c++ -fobjc-arc

#define NS_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION
#include <Metal/Metal.hpp>
#include <Foundation/Foundation.hpp>

#include "metal_bridge.h"
#include <fstream>
#include <string>

struct noul_metal_ctx {
    MTL::Device               *device;
    MTL::CommandQueue         *queue;
    MTL::ComputePipelineState *pipeline;
};

static MTL::Library *load_msl_library(MTL::Device *device, const char *path) {
    std::ifstream f(path);
    std::string src((std::istreambuf_iterator<char>(f)),
                     std::istreambuf_iterator<char>());
    NS::Error *err = nullptr;
    auto ns_src = NS::String::string(src.c_str(), NS::UTF8StringEncoding);
    return device->newLibrary(ns_src, nullptr, &err);
}

noul_metal_ctx *noul_metal_create(void) {
    auto *ctx    = new noul_metal_ctx;
    ctx->device  = MTL::CreateSystemDefaultDevice();
    ctx->queue   = ctx->device->newCommandQueue();

    auto *lib = load_msl_library(ctx->device, "noul_decision.metal");
    if (!lib) { delete ctx; return nullptr; }

    NS::Error *err = nullptr;
    auto *fn = lib->newFunction(
        NS::String::string("noul_decision_head", NS::UTF8StringEncoding));
    ctx->pipeline = ctx->device->newComputePipelineState(fn, &err);
    fn->release();
    lib->release();
    return ctx;
}

void noul_metal_destroy(noul_metal_ctx *ctx) {
    if (!ctx) return;
    ctx->pipeline->release();
    ctx->queue->release();
    ctx->device->release();
    delete ctx;
}

// Zero-copy allocation on Apple Silicon (shared memory).
void *noul_metal_alloc(noul_metal_ctx *ctx, size_t bytes) {
    auto *buf = ctx->device->newBuffer(bytes, MTL::ResourceStorageModeShared);
    return buf->contents();
}

void noul_metal_free(noul_metal_ctx *ctx, void *ptr) {
    (void)ctx; (void)ptr; // MTLBuffer released via ARC / manual release
}

int noul_metal_decision_head(
    noul_metal_ctx *ctx,
    void *input, void *weights, void *bias, void *logits,
    uint32_t hidden_dim, uint32_t num_classes)
{
    auto *cmd = ctx->queue->commandBuffer();
    auto *enc = cmd->computeCommandEncoder();
    enc->setComputePipelineState(ctx->pipeline);
    enc->setBuffer((MTL::Buffer *)input,   0, 0);
    enc->setBuffer((MTL::Buffer *)weights, 0, 1);
    enc->setBuffer((MTL::Buffer *)bias,    0, 2);
    enc->setBuffer((MTL::Buffer *)logits,  0, 3);
    enc->setBytes(&hidden_dim,   sizeof(hidden_dim),   4);
    enc->setBytes(&num_classes,  sizeof(num_classes),  5);

    auto grid       = MTL::Size::Make(num_classes, 1, 1);
    auto threadgroup = MTL::Size::Make(32, 1, 1);
    enc->dispatchThreadgroups(grid, threadgroup);
    enc->endEncoding();
    cmd->commit();
    cmd->waitUntilCompleted();
    return 0;
}
