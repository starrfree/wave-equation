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
constant float dt(1);
constant float maxc(0.7);
constant float damp(1);
constant float aCeil(0.95);

kernel void compute_kernel(device Tile *tileMapIn  [[ buffer(0) ]],
                           device Tile *tileMapOut  [[ buffer(1) ]],
                           device Tile *energyMap  [[ buffer(2) ]],
                           texture2d<half, access::read> boundaryTexture [[ texture(0) ]],
                           constant Parameters *params [[ buffer(3) ]],
                           uint2 gid [[ thread_position_in_grid ]]) {
    float xRatio((float)boundaryTexture.get_width() / (float)params->width);
    float yRatio((float)boundaryTexture.get_height() / (float)params->height);
    half4 tcolor(boundaryTexture.read(uint2(float(gid.x) * xRatio, float(gid.y) * yRatio)));
    uint id(indexFromCoordinates(gid, params->width));
    float a(tcolor.a);
    if (a > aCeil) {
        a = 1;
    }
    float outValue;
    if (gid.x == 1) { // && false // (int)gid.x == params->width / 2 && (int)gid.y == params->height / 2
        outValue = 0.6 * cos(xRatio * float(params->step) / 20) * (params->step < 120 * 10 / xRatio);
        tileMapOut[id].value = outValue;
    } else {
        float middle = tileMapIn[id].value;
        float before = tileMapIn[id].prevValue;
        float boundary = before;//middle;//
        float right = boundary;
        if (int(gid.x) < params->width - 1 && a < aCeil) {
            right = tileMapIn[id + 1].value;
        }
        float left = boundary;
        if (int(gid.x) > 0 && a < aCeil) {
            left = tileMapIn[id - 1].value;
        }
        float bottom = boundary;
        if (int(gid.y) < params->height - 1 && a < aCeil) {
            bottom = tileMapIn[id + params->width].value;
        }
        float top = boundary;
        if (int(gid.y) > 0 && a < aCeil) {
            top = tileMapIn[id - params->width].value;
        }
        float dfx = right - 2 * middle + left;
        float dfy = top - 2 * middle + bottom;
        if (a < aCeil) {
            float c(maxc * (1 - a));
            float newValue = c*c * (dfx / (dx * dx) + dfy / (dy * dy)) * dt*dt + 2 * middle - before;
            outValue = newValue * damp;
            tileMapOut[id].value = outValue;
            tileMapOut[id].prevValue = middle;
        } else {
            outValue = 0;
            tileMapOut[id].value = outValue;
            tileMapOut[id].prevValue = 0;
        }
    }
    energyMap[id].value += outValue * outValue;
}

kernel void copy_to_texture(texture2d<half, access::write> texture [[ texture(0) ]],
                 device Tile *tileMapIn  [[ buffer(0) ]],
                 device Tile *tileMapOut  [[ buffer(1) ]],
                 device Tile *energyMap  [[ buffer(2) ]],
                 texture2d<half, access::read> boundaryTexture [[ texture(1) ]],
                 texture2d<half, access::read> gradient [[ texture(2) ]],
                 constant Parameters *params [[ buffer(3) ]],
                 uint2 gid [[ thread_position_in_grid ]]) {
    float xRatio(float(params->textureWidth) / float(params->width));
    float yRatio(float(params->textureHeight) / float(params->height));
    uint x(xRatio * gid.x);
    uint y(yRatio * gid.y);
    uint id(indexFromCoordinates(gid, params->width));
    tileMapIn[id].value = tileMapOut[id].value;
    tileMapIn[id].prevValue = tileMapOut[id].prevValue;

    float value = max(min(tileMapOut[id].value / 2 + 0.5, 1.0), 0.0);
//    float value = max(min(energyMap[id].value / float(params->step + 1), 1.0), 0.0);
    float h(gradient.get_height() - 1);
    half3 color;
    if (h == 0) {
        color = half3(value);
    } else {
        color = gradient.read(uint2(0.0, value * h)).rgb;
    }
//    if (value <= 1.2) {
//        color *= 0.2;
//    }
    if (isinf(value)) {
        color = half3(0, 1, 0);
    }
    if (isnan(value)) {
        color = half3(1, 0, 1);
    }
    for (int i(0); i < xRatio; i++) {
        for (int j(0); j < yRatio; j++) {
            float xtRatio((float)boundaryTexture.get_width() / (float)params->textureWidth);
            float ytRatio((float)boundaryTexture.get_height() / (float)params->textureHeight);
            half4 tcolor(boundaryTexture.read(uint2(float(x + i) * xtRatio, float(y + j) * ytRatio)));
            float t(tcolor.a * tcolor.a);
            color = color * (1 - t) + half3(0, 0, 0.2) * t;
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
