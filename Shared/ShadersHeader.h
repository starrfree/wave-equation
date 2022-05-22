//
//  ShadersHeader.h
//  MetalShader
//
//  Created by Eliott Morgensztern on 25/07/2021.
//

#ifndef ShadersHeader_h
#define ShadersHeader_h
using namespace metal;

struct Tile {
    float value;
    float prevValue;
};

struct Parameters {
    int width;
    int height;
    int textureWidth;
    int textureHeight;
    int step;
};

uint indexFromCoordinates(uint2 coordinates, uint width);
uint hash(uint ste);
float random(uint ste);

#endif /* ShadersHeader_h */
