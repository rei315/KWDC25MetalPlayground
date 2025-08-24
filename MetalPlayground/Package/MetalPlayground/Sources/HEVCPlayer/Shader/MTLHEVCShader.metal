//
// default.metal
// Playground
//
// Created by rei315 on 2025/06/30.
// Copyright © 2025 rei315. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexUniform {
  float2 scale;
};

struct VertexOutput {
  float2 textureCoordinate [[user(texcoord)]];
  float4 position [[position]];
};

vertex VertexOutput vertex_function(uint vertexIdentifier       [[vertex_id]],
                                       constant VertexUniform& uni [[buffer(0)]])
{
  float2 positions[4] = {
    float2(-1.0, -1.0),
    float2( 1.0, -1.0),
    float2(-1.0,  1.0),
    float2( 1.0,  1.0)
  };
  
  float2 textureCoordinates[4] = {
    float2(0.0, 1.0),
    float2(1.0, 1.0),
    float2(0.0, 0.0),
    float2(1.0, 0.0)
  };
  
  float2 scaledPosition = positions[vertexIdentifier] * uni.scale;
  
  VertexOutput out;
  out.position  = float4(scaledPosition, 0.0, 1.0);
  out.textureCoordinate  = textureCoordinates[vertexIdentifier];
  return out;
}

fragment float4 fragment_function(VertexOutput in [[stage_in]],
                                     texture2d<float> yTex [[texture(0)]],
                                     texture2d<float> cbcrTex [[texture(1)]],
                                     texture2d<float> alphaTex [[texture(2)]],
                                     sampler s [[sampler(0)]]) {
  const float4x4 ycbcrToRGBTransform = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));
  float2 texCoords = in.textureCoordinate;
  
  float y = yTex
    .sample(s, texCoords).r;
  float2 cbcr = cbcrTex
    .sample(s, texCoords).rg;
  float a = alphaTex
    .sample(s, texCoords).r;
  
  float4 yuv = float4(y, cbcr, 1.0f);
  
  yuv
    .r = (yuv.r - (16.0f/255.0f)) * (255.0f/(235.0f-16.0f));
  yuv
    .g = (yuv.g - (16.0f/255.0f)) * (255.0f/(240.0f-16.0f));
  yuv
    .b = (yuv.b - (16.0f/255.0f)) * (255.0f/(240.0f-16.0f));
  
  float4 rgb = ycbcrToRGBTransform * yuv;
  
  return float4(rgb.r, rgb.g, rgb.b, a);
}
