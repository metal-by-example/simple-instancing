
#include <metal_stdlib>
using namespace metal;

#include "Bridging-Header.h"

#if USE_VERTEX_DESCRIPTOR

struct VertexIn {
    float4 position [[attribute(0)]];
    float4 center   [[attribute(1)]];
    float radius    [[attribute(2)]];
    float4 color    [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant float4x4 &projectionMatrix [[buffer(2)]])
{
    VertexOut out;
    out.position = projectionMatrix * float4(in.center.xy + in.radius * in.position.xy, 0.0f, 1.0f);
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}

#else

struct VertexIn {
    float2 position;
};

struct InstanceConstants {
    packed_float2 center;
    float radius;
    packed_float3 color;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertex_main(device VertexIn const *vertices [[buffer(0)]],
                             constant InstanceConstants *instances [[buffer(1)]],
                             constant float4x4 &projectionMatrix [[buffer(2)]],
                             uint vertexID [[vertex_id]],
                             uint instanceID [[instance_id]])
{
    VertexIn vertexIn = vertices[vertexID];
    InstanceConstants instance = instances[instanceID];

    VertexOut out;
    out.position = projectionMatrix * float4(instance.center.xy + instance.radius * vertexIn.position.xy, 0.0f, 1.0f);
    out.color = float4(instance.color, 1.0f);
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}

#endif
