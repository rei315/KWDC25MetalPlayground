//
// hello_metal_shader.metal
// Playground
//
// Created by rei315 on 2025/07/03.
// Copyright © 2025 rei315. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexData {
  float2 position;
  float4 color;
};

struct GridParams {
  uint columns;
  uint rows;
  float radius;
};

struct RasterizerData {
  float4 position [[position]];
  float4 color;
};

vertex RasterizerData helloMetalVertex(
                                   uint vertexID [[vertex_id]],
                                   uint instanceID [[instance_id]],
                                   constant VertexData *vertexData [[buffer(0)]],
                                   constant simd_uint2 *viewportSize [[buffer(1)]],
                                   constant GridParams &grid [[buffer(2)]]
                                   ) {
  float sideLength = sqrt(3.0) * grid.radius;
  float height = 1.5 * grid.radius;
  
  uint col = instanceID % grid.columns;
  uint row = instanceID / grid.columns;
  
  float2 basePos = vertexData[vertexID].position;
  
  float offsetX = col * sideLength + grid.radius;
  float offsetY = row * height + grid.radius;
  
  float2 pixelPos = basePos + float2(offsetX, offsetY);
  
  float2 vpSize = float2(viewportSize->x, viewportSize->y);
  
  float xClip = (pixelPos.x / vpSize.x) * 2.0 - 1.0;
  float yClip = 1.0 - (pixelPos.y / vpSize.y) * 2.0;
  
  RasterizerData out;
  out.position = float4(xClip, yClip, 0, 1);
  out.color = vertexData[vertexID].color;
  
  return out;
}

fragment float4 helloMetalFragment(RasterizerData in [[stage_in]])
{
  float2 pos = in.position.xy / in.position.w;
  float2 uv = fract(pos * 0.5 + 0.5);
  float3 accumulator = float3(0.0);
  
  for (int i = 1; i <= 4; ++i) {
    float fi = float(i);
    float2 fuv = uv * fi;
    
    float tanInput = clamp(fuv.x * 5.0 + fuv.y * 5.0, -1.55, 1.55);
    
    float logInput = max(1.0 + abs(fuv.x + fuv.y), 0.0001);
    
    float powBaseSin = max(abs(sin(fi)) + 0.01, 0.0001);
    float powBaseCos = max(abs(cos(fi)) + 0.01, 0.0001);
    
    float sinVal = sin(fuv.x * 40.0 + sin(fuv.y * 20.0));
    float cosVal = cos(fuv.y * 30.0 + cos(fuv.x * 10.0));
    float tanVal = tan(tanInput);
    float logExp = log(logInput) * exp(-abs(fuv.x * fuv.y));
    float powVal = pow(powBaseSin, 2.0) + pow(powBaseCos, 2.0);
    float advanced = sinh(fuv.x) * cosh(fuv.y) + atan2(fuv.y, fuv.x + 0.01);
    
    float3 combined = float3(
                             sinVal + tanVal * 0.01,
                             cosVal + logExp,
                             powVal + advanced
                             );
    
    accumulator += combined / fi;
  }
  
  float3 baseColor = in.color.rgb;
  float3 result = baseColor + 0.8 * sin(accumulator + baseColor * 0.25);
  
  return float4(clamp(result, 0.0, 1.0), in.color.a);
}
