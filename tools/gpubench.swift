// swift ~/Claude/wex-reset-capture/gpubench.swift
// Times small Metal workloads: round-trip latency of an empty command buffer,
// a compute kernel over 16M floats, and a 4K blit. Prints medians in ms.
import Metal

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let source = """
#include <metal_stdlib>
using namespace metal;
kernel void work(device float *d [[buffer(0)]], uint i [[thread_position_in_grid]]) {
    float x = d[i];
    for (int k = 0; k < 64; ++k) x = fma(x, 1.0001f, 0.5f);
    d[i] = x;
}
"""
let library = try! device.makeLibrary(source: source, options: nil)
let pipeline = try! device.makeComputePipelineState(function: library.makeFunction(name: "work")!)
let count = 16 << 20
let buffer = device.makeBuffer(length: count * 4, options: .storageModePrivate)!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 3840, height: 2160, mipmapped: false)
desc.storageMode = .private
let src = device.makeTexture(descriptor: desc)!, dst = device.makeTexture(descriptor: desc)!

func time(_ runs: Int, _ encode: (MTLCommandBuffer) -> Void) -> Double {
    var samples: [Double] = []
    for _ in 0..<runs {
        let cb = queue.makeCommandBuffer()!
        encode(cb)
        let t = DispatchTime.now().uptimeNanoseconds
        cb.commit(); cb.waitUntilCompleted()
        samples.append(Double(DispatchTime.now().uptimeNanoseconds - t) / 1e6)
    }
    return samples.sorted()[runs / 2]
}

print("device:", device.name)
print(String(format: "empty command buffer: %.2f ms", time(50) { _ in }))
print(String(format: "compute 16M x 64 fma: %.2f ms", time(20) { cb in
    let e = cb.makeComputeCommandEncoder()!
    e.setComputePipelineState(pipeline); e.setBuffer(buffer, offset: 0, index: 0)
    e.dispatchThreads(MTLSize(width: count, height: 1, depth: 1),
                      threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
    e.endEncoding()
}))
print(String(format: "blit 3840x2160: %.2f ms", time(20) { cb in
    let b = cb.makeBlitCommandEncoder()!; b.copy(from: src, to: dst); b.endEncoding()
}))
