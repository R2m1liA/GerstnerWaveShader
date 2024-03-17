Shader "Unlit/Water"
{
    Properties
    {
        [MainTex] _MainTex("Albedo (RGB)", 2D) = "white" {}
        _Color("Color", Color) = (1, 1, 1, 1)
        _Metallic("Metallic", Range(0, 1)) = 0.0
        _Gloss("Gloss", Range(8, 20)) = 8.0
        
        [Header(FlowMap)]
        [NoScaleOffset]_FlowMap("Flow Map", 2D) = "black" {}
        _UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
        _VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
        _Tiling("Tiling", Float) = 1
        _Speed("Speed", Float) = 1
        _FlowStrength("Flow Strength", Float) = 1
        _FlowOffset("Flow Offset", Float) = 0
        
        [Header(NormalMap)]
        [NoScaleOffset]_NomralMap("Normal Map", 2D) = "black" {}
        _NormalMap_Intensity("Normal Map Intensity", Range(0, 1)) = 1
        [Toggle(_INVERT_NORMAL_Y)]_INVERT_NORMAL_Y("Invert Normal Y", Float) = 0
        
        [Header(Tesselation)]
        _TessellationEdge ("Tessellation Edge", Range(1, 64)) = 1
        _TessellationInside ("Tessellation Inside", Range(1, 64)) = 1
        _TessellationEdgeLength("Tessellation Edge Length", Range(0.001, 1)) = 0.5
        
        [Header(Wave)]
        [Toggle(_ENABLE_WAVE)] _EnableWave("Enable Wave", Float) = 0
        _WaveCount("Wave Count", Int) = 1
        _WaveLengthMax("Wave Length Max", Float) = 1
        _WaveLengthMin("Wave Length Min", Float) = 0.5
        _SteepnessMax("Steepness Max", Float) = 0.9
        _SteepnessMin("Steepness Min", Float) = 0.1
        _WaveSpeed("Wave Speed", Float) = 1
        _RandomDirection("Random Direction", Float) = 0.5
        _Direction("Direction", Vector) = (1, 0, 0, 0)
        
        [Header(WaterColor)]
        _WaterColor1("Water Color 1", Color) = (0, 0, 1, 1)
        _WaterColor2("Water Color 2", Color) = (0, 0, 1, 1)
        _WaterSpeed("Water Speed", Range(0, 1)) = 0.1
        _MaxDepth("Max Depth", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent"
             "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "Forward"
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hull
            #pragma domain doma
            
            #pragma multi_compile _ SHADOW_SCREEN
            #pragma multi_compile _ _ENABLE_WAVE
            #pragma multi_compile _ _INVERT_NORMAL_Y
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #include "Wave.hlsl"
            #include "Flow.hlsl"
            
            struct pdata
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };

            struct tessFactor
            {
                float edgeTess[3] : SV_Tessfactor;
                float insideTess : SV_InsideTessFactor;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float4 positionOS : TEXCOORD3;
                float3 positionVS : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                float4 color : COLOR;
            };

            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_FlowMap);
            SAMPLER(sampler_FlowMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;

                float4 _FlowMap_ST;
                float4 _NormalMap_ST;
            
                float _TessellationEdgeLength;
                half _TessellationEdge;
                half _TessellationInside;
            
                float _Gloss;

                int _WaveCount;
                float _WaveLengthMax;
                float _WaveLengthMin;
                float _SteepnessMax;
                float _SteepnessMin;
                float _WaveSpeed;
                float _RandomDirection;
                vector _Direction;

                half4 _WaterColor1;
                half4 _WaterColor2;
                half _WaterSpeed;

                half _MaxDepth;

                float _UJump;
                float _VJump;
                float _Tiling;
                float _Speed;
                float _FlowStrength;
                float _FlowOffset;

                float _NormalMap_Intensity;
            CBUFFER_END

            half3 GetNormalMap(float3 normal, float4 tangent, float2 uv, float intensity, bool invertY)
            {
                // 计算副切线
                float3 bitangent = cross(normal, tangent) * tangent.w;
                float3 normalMap = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv.xy
                    ), intensity);
                float3 newNormal = normalize(normalMap.x * tangent +
                    normalMap.y * (invertY ? -1 : 0) * bitangent +
                    normalMap.z * normal);
                return newNormal;
            }
            
            pdata vert(pdata IN)
            {
                pdata OUT;
                
                OUT.positionOS = IN.positionOS;
                OUT.uv = IN.uv;
                OUT.normal = IN.normal;
                OUT.color = IN.color;
                return OUT;
            }

            float TessellationEdgeFactor(pdata cp0, pdata cp1)
            {
                float3 p0 = mul(unity_ObjectToWorld, float4(cp0.positionOS.xyz,1)).xyz;
                float3 p1 = mul(unity_ObjectToWorld, float4(cp1.positionOS.xyz,1)).xyz;
                float edgeLength = distance(p0, p1);
                float3 edgeCenter = (p0 + p1) * 0.5;
                float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);
                return edgeLength / (_TessellationEdgeLength * pow(viewDistance, 2) * 0.01);
            }

            tessFactor PatchFunc(InputPatch<pdata, 3> patch)
            {
                tessFactor f;
                f.edgeTess[0] = TessellationEdgeFactor(patch[1], patch[2]);
                f.edgeTess[1] = TessellationEdgeFactor(patch[2], patch[0]);
                f.edgeTess[2] = TessellationEdgeFactor(patch[0], patch[1]);
                f.insideTess = (f.edgeTess[0] + f.edgeTess[1] + f.edgeTess[2]) / 3;
                return f;
            }

            [domain("tri")]
            [partitioning("integer")]
            [outputcontrolpoints(3)]
            [outputtopology("triangle_cw")]
            [patchconstantfunc("PatchFunc")]
            pdata hull(InputPatch<pdata,3> patch, uint id : SV_OutputControlPointID)
            {
                pdata o;
                o.positionOS = patch[id].positionOS;
                o.uv = patch[id].uv;
                o.normal = patch[id].normal;
                o.color = (step(-0.1, id) - step(0.1, id)) * half4(1, 0, 0, 0) +
                    (step(0.9, id) - step(1.1, id)) * half4(0, 1, 0, 0) +
                        (step(1.9, id) - step(2.1, id)) * half4(0, 0, 1, 0);
                return o;
            }
            
            [domain("tri")]
            Varyings doma(tessFactor i, OutputPatch<pdata, 3> patch, float3 bary : SV_DomainLocation)
            {
                Varyings OUT = (Varyings)0;
                OUT.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
                OUT.uv = patch[0].uv * bary.x + patch[1].uv * bary.y + patch[2].uv * bary.z;
                OUT.normal = patch[0].normal * bary.x + patch[1].normal * bary.y + patch[2].normal * bary.z;
                OUT.color = patch[0].color * bary.x + patch[1].color * bary.y + patch[2].color * bary.z;

                // 波形模拟
                #if _ENABLE_WAVE
                    Gerstner gerstner = GerstnerWave(_Direction, OUT.positionOS.xyz, _WaveCount, _WaveLengthMax, _WaveLengthMin, _SteepnessMax, _SteepnessMin, _WaveSpeed, _RandomDirection);
                    float3 positionWS = gerstner.positionWS;
                    float3 binormal = gerstner.binormal;
                    float3 tangent = gerstner.tangent;
                    float3 normalWS = normalize(cross(binormal, tangent));
                    
                    OUT.positionOS.xyz = positionWS;
                    OUT.normal = normalWS;
                #else
                    OUT.normal = TransformObjectToWorldNormal(OUT.normal);
                #endif

                OUT.positionOS = OUT.positionOS;
                OUT.positionWS = mul(unity_ObjectToWorld, OUT.positionOS).xyz;
                OUT.positionHCS = TransformObjectToHClip(OUT.positionOS);
                OUT.positionVS = TransformWorldToView(OUT.positionWS);
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                return OUT;
            }

            // The fragment shader definition.
            half4 frag(Varyings IN) : SV_Target
            {
                float2 flowVector = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, IN.uv).rg * 2 - 1;
                flowVector *= _FlowStrength;
                float noise = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, IN.uv).a;
                float time = _Time.y * _Speed + noise;
                float2 jump = float2(_UJump, _VJump);
                float3 uvwA = FlowUVW(IN.uv, flowVector, jump, _FlowOffset, _Tiling, time, false);
                float3 uvwB = FlowUVW(IN.uv, flowVector, jump, _FlowOffset, _Tiling, time, true);

                half3 normalA = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uvwA.xy));
                half3 normalB = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uvwB.xy));
                half3 normalWS = lerp(normalA, normalB, uvwA.z);
                Light mainLight = GetMainLight();
                
                half4 texA = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvwA.xy) * uvwA.z;
                half4 texB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvwB.xy) * uvwB.z;
                half4 col = (texA + texB) * _Color;
                
                return col;
            }
            ENDHLSL
        }
    }

    CustomEditor "StaloSRPShaderGUI"
}
