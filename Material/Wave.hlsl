#ifndef _WAVE_INCLUDED
#define _WAVE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Gerstner
{
    float3 positionWS;
    float3 binormal;
    float3 tangent;
};

float Random(int seed)
{
    return frac(sin(dot(float2(seed, 2), float2(12.9898, 78.233))) * 2) - 1;
}

Gerstner GerstnerWave(vector direction, float3 positionWS, int waveCount, float waveLengthMax, float waveLengthMin, float steepnessMax, float steepnessMin, float waveSpeed, float randomDirection)
{
    Gerstner gerstner;
    float3 P;
    float3 B;
    float3 T;

    for(int i = 0; i < waveCount; i ++)
    {
        float step = (float) i / (float) waveCount;

        float2 d = float2(Random(i), Random(2 * i));
        d = normalize(lerp(normalize(direction.xy), d, randomDirection));

        float waveLength = lerp(waveLengthMax, waveLengthMin, step);
        float steepness = lerp(steepnessMax, steepnessMin, step) / waveCount;

        float k = 2 * 3.14159 / waveLength;
        float a = steepness / k;
        float2 waveVector = k * d;
        float value = dot(waveVector, positionWS.xz) - waveSpeed * _Time.y;

        P.x += d.x * a * cos(value);
        P.y += a * sin(value);
        P.z += d.y * a * cos(value);

        T.x += d.x * d.x * k * a * -sin(value);
        T.y += d.x * k * a * cos(value);
        T.z += d.x * d.y * k * a * -sin(value);

        B.x += d.x * d.y * k * a * -sin(value);
        B.y += d.y * k * a * cos(value);
        B.z += d.y * d.y * k * a * -sin(value);
    }

    gerstner.positionWS.x = positionWS.x + P.x;
    gerstner.positionWS.y = P.y;
    gerstner.positionWS.z = positionWS.z + P.z;
    gerstner.tangent = float3(1 + T.x, T.y, T.z);
    gerstner.binormal = float3(B.x, B.y, 1 + B.z);

    return gerstner;
}

#endif
