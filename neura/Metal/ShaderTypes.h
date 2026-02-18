#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct {
    float time;
    simd_float2 resolution;
    float windSpeed;
    float windStrength;
    float dayTime;
} MeadowUniforms;

#endif /* ShaderTypes_h */
