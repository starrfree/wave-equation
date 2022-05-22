//
//  Shaders.metal
//  MetalShader
//
//  Created by Eliott Morgensztern on 25/07/2021.
//

#include <metal_stdlib>
#include "ShadersHeader.h"

constant float dx(1);
constant float dy(1);
constant float dt(2);
constant float c(0.3);

kernel void compute_kernel(device Tile *tileMapIn  [[ buffer(0) ]],
                           device Tile *tileMapOut  [[ buffer(1) ]],
                           constant Parameters *params [[ buffer(2) ]],
                           uint2 gid [[ thread_position_in_grid ]]) {
    uint id(indexFromCoordinates(gid, params->width));
    float middle = tileMapIn[id].value;
    float before = tileMapIn[id].prevValue;
    float right = middle;
    if (int(gid.x) < params->width - 1) {
        right = tileMapIn[id + 1].value;
    }
    float left = middle;
    if (int(gid.x) > 0) {
        left = tileMapIn[id - 1].value;
    }
    float bottom = middle;
    if (int(gid.y) < params->height - 1) {
        bottom = tileMapIn[id + params->width].value;
    }
    float top = middle;
    if (int(gid.y) > 0) {
        top = tileMapIn[id - params->width].value;
    }
    float dfx = right - 2 * middle + left;
    float dfy = top - 2 * middle + bottom;
    tileMapOut[id].value = c*c * (dfx / (dx * dx) + dfy / (dy * dy)) * dt*dt + 2 * middle - before;
    tileMapOut[id].prevValue = middle;
}

kernel void copy_to_texture(texture2d<half, access::write> texture [[ texture(0) ]],
                 device Tile *tileMapIn  [[ buffer(0) ]],
                 device Tile *tileMapOut  [[ buffer(1) ]],
                 constant Parameters *params [[ buffer(2) ]],
                 uint2 gid [[ thread_position_in_grid ]]) {
    float xRatio(float(params->textureWidth) / float(params->width));
    float yRatio(float(params->textureHeight) / float(params->height));
    uint x(xRatio * gid.x);
    uint y(yRatio * gid.y);
    uint id(indexFromCoordinates(gid, params->width));
    tileMapIn[id].value = tileMapOut[id].value;
    tileMapIn[id].prevValue = tileMapOut[id].prevValue;
    
    float value = tileMapOut[id].value / 2 + 0.5;
    half3 color(value);
    if (isinf(value)) {
        color = half3(1, 0, 1);
    }
    if (isnan(value)) {
        color = half3(0, 1, 1);
    }
    for (int i(0); i < xRatio; i++) {
        for (int j(0); j < yRatio; j++) {
            texture.write(half4(color, 1), uint2(x + i, y + j));
        }
    }
}

uint indexFromCoordinates(uint2 coordinates, uint width) {
    return coordinates.x + coordinates.y * width;
}

float random(uint ste) {
    return float(hash(ste)) / 4294967295.0;
}

uint hash(uint ste) {
    ste ^= 2747636419u;
    ste *= 2654435769u;
    ste ^= ste >> 16;
    ste *= 2654435769u;
    ste ^= ste >> 16;
    ste *= 2654435769u;
    return ste;
}
