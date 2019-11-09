﻿Shader "0_Custom/Cubemap"
{
    Properties
    {
        _BaseColor ("Color", Color) = (0, 0, 0, 1)
        _Roughness ("Roughness", Range(0.0001, 1)) = 1
        _Metallic ("Metallic", Range(0, 1)) = 1
        _Cube ("Cubemap", CUBE) = "" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            
            #define EPS 01e-9

            struct appdata
            {
                float4 vertex : POSITION;
                fixed3 normal : NORMAL;
            };

            struct v2f
            {
                float4 clip : SV_POSITION;
                float4 pos : TEXCOORD1;
                fixed3 normal : NORMAL;
            };

            float4 _BaseColor;
            float _Roughness;
            float _Metallic;
            
            samplerCUBE _Cube;
            half4 _Cube_HDR;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            uint Hash(uint s)
            {
                s ^= 2747636419u;
                s *= 2654435769u;
                s ^= s >> 16;
                s *= 2654435769u;
                s ^= s >> 16;
                s *= 2654435769u;
                return s;
            }
            
            float Random(uint seed)
            {
                return float(Hash(seed)) / 4294967295.0; // 2^32-1
            }
            
            float3 SampleColor(float3 direction)
            {   
                half4 tex = texCUBE(_Cube, direction);
                return DecodeHDR(tex, _Cube_HDR).rgb;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.pos.xyz);
                float3 viewRefl = reflect(-viewDirection.xyz, normal);
                
                const int SAMPLES = 5000;
                
                float3 diffuse = 0;
                float3 specular = 0;
                float sumPDiffuse = 0;
                float sumPSpecular = 0;
                
                for (int i = 0; i < SAMPLES; i++)
                {
                    float u = Random(2 * i);
                    float v = Random(2 * i + 1);
                    float phi = u * UNITY_PI * 2;
                    float cosTheta = 2 * v - 1;
                    float sinTheta = sqrt(1 - cosTheta * cosTheta);
                    float3 sampleDir = float3(
                        cos(phi) * sinTheta,
                        sin(phi) * sinTheta,
                        cosTheta
                    );
                
                    float3 sample = SampleColor(sampleDir);
                    float attenuation = dot(normal, sampleDir);
                    
                    float pSpecular = pow(max(0, dot(viewRefl, sampleDir)), 1/_Roughness + EPS) * (attenuation > 0);
                    float pDiffuse = attenuation > 0;
                    sumPSpecular += pSpecular;
                    sumPDiffuse += pDiffuse;
                    
                    diffuse += sample * max(attenuation, 0);
                    specular += sample * pSpecular;
                }
                // Multiply by half-sphere area and by density function.
                specular = (specular / sumPSpecular) * (2 * UNITY_PI) * (1 / UNITY_PI);
                diffuse = (diffuse / sumPDiffuse) * (2 * UNITY_PI) * (1 / UNITY_PI);
                
                return half4(lerp(_BaseColor.rgb * diffuse, specular, _Metallic), 1);
            }
            ENDCG
        }
    }
}
