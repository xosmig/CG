﻿Shader "0_Custom/SH"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)
        _Glossiness ("Glossiness", Float) = 0
        _SpecularMipLevel ("SpecularMipLevel", Int) = 0
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
            float _Glossiness;
            float _SpecularMipLevel;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }
            
            // (L=1; M=1), (L=1; M=0), (L=1; M=-1), (L=0, M=0)
            uniform half4 SH_0_1_r;
            uniform half4 SH_0_1_g;
            uniform half4 SH_0_1_b;
            
            // (L=2; M=-2), (L=2; M=-1), (L=2; M=1), (L=2, M=0)
            uniform half4 SH_2_r;
            uniform half4 SH_2_g;
            uniform half4 SH_2_b;
            
            // (L=2; M=2)
            uniform half4 SH_2_rgb;
            
            half pow2(half f)
            {
                return f * f;
            }
            
            // normal.w is expected to be 1
            half3 SH_3_Order(half4 normal)
            {
                half3 res;
                res.r = dot(SH_0_1_r, normal);
                res.g = dot(SH_0_1_g, normal);
                res.b = dot(SH_0_1_b, normal);
                
                half4 vB = half4(normal.xyx * normal.yzz, 3 * pow2(normal.z) - 1);
                res.r += dot(SH_2_r, vB);
                res.g += dot(SH_2_g, vB);
                res.b += dot(SH_2_b, vB);
                
                half vC = pow2(normal.x) - pow2(normal.y);
                res += SH_2_rgb.rgb * vC;
                
                return res;
            }
            
            half3 maprg(half3 sh)
            {
                if (sh.r > 0)
                {
                    return half3(sh.r, 0, 0);
                }
                else
                {
                    return half3(0, 0, -sh.r);
                }
            }

            fixed4 frag (v2f i) : SV_Target
            {
                const float3 normal = normalize(i.normal);
                const float3 viewDirection = normalize(UnityWorldSpaceViewDir(i.pos));
                const float3 reflectDirection = reflect(-viewDirection, i.normal);
                
                float3 diffuse = SH_3_Order(float4(normal, 1));
                float4 specular = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectDirection, _SpecularMipLevel);
                
                return half4(lerp(_BaseColor.rgb * diffuse, specular.rgb, _Glossiness), 1);
            }
            ENDCG
        }
    }
}
