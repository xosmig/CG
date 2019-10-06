Shader "Custom/BrokenShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainXTex ("Albedo X (RGB)", 2D) = "red" {}
        _MainYTex ("Albedo Y (RGB)", 2D) = "green" {}
        _MainZTex ("Albedo Z (RGB)", 2D) = "blue" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Pass
        {
            // indicate that our pass is the "base" pass in forward
            // rendering pipeline. It gets ambient and main directional
            // light data set up; light direction in _WorldSpaceLightPos0
            // and color in _LightColor0
            Tags {"LightMode"="ForwardBase"}
        
            CGPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uvX : TEXCOORD0;
                float2 uvY : TEXCOORD1;
                float2 uvZ : TEXCOORD2;
                fixed3 normal : NORMAL;
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uvX = v.vertex.zy;
                o.uvY = v.vertex.xz;
                o.uvZ = v.vertex.xy;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }
            
            sampler2D _MainXTex;
            sampler2D _MainYTex;
            sampler2D _MainZTex;

            fixed4 frag (v2f i) : SV_Target
            {
                half nl = max(0, dot(i.normal, _WorldSpaceLightPos0.xyz));
                half3 light = nl * _LightColor0;
                light += ShadeSH9(half4(i.normal,1));
                
                fixed4 col = tex2D(_MainXTex, i.uvX) * abs(i.normal.x);
                if (i.normal.y > 0) {
                    col += tex2D(_MainYTex, i.uvY) * abs(i.normal.y);
                }
                col += tex2D(_MainZTex, i.uvZ) * abs(i.normal.z);

                col.rgb *= light;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
