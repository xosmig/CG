Shader "Custom/POM"
{
    Properties {
        // normal map texture on the material,
        // default to dummy "flat surface" normalmap
        _NormalMap("Normal Map", 2D) = "bump" {}
        _MainTex("Texture", 2D) = "grey" {}
        _HeightMap("Height Map", 2D) = "white" {}
        _MaxHeight("Max Height", Float) = 0.01
        _StepLength("Step Length", Float) = 0.000001
        _MaxStepCount("Max Step Count", Int) = 64
        _AmbientLight("Ambient Light", Color) = (0.4, 0.4, 0.4, 1)
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            float lengthSqr(float2 vec) {
                return dot(vec, vec);
            }
            
            inline float LinearEyeDepthToOutDepth(float z)
            {
                return (1 - _ZBufferParams.w * z) / (_ZBufferParams.z * z);
            }

            struct v2f {
                float3 worldPos : TEXCOORD0;
                // these three vectors will hold a 3x3 rotation matrix
                // that transforms from tangent to world space
                half3 tspace0 : TEXCOORD1; // tangent.x, bitangent.x, normal.x
                half3 tspace1 : TEXCOORD2; // tangent.y, bitangent.y, normal.y
                half3 tspace2 : TEXCOORD3; // tangent.z, bitangent.z, normal.z
                half3 worldSurfaceNormal : TEXCOORD4;
                // texture coordinate for the normal map
                float2 uv : TEXCOORD5;
                float4 clip : SV_POSITION;
            };

            // vertex shader now also needs a per-vertex tangent vector.
            // in Unity tangents are 4D vectors, with the .w component used to
            // indicate direction of the bitangent vector.
            // we also need the texture coordinate.
            v2f vert (float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT, float2 uv : TEXCOORD0)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(vertex);
                o.worldPos = mul(unity_ObjectToWorld, vertex).xyz;
                half3 wNormal = UnityObjectToWorldNormal(normal);
                half3 wTangent = UnityObjectToWorldDir(tangent.xyz);
                // compute bitangent from cross product of normal and tangent
                half tangentSign = tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                // output the tangent space matrix
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
                o.uv = uv;
                o.worldSurfaceNormal = normal;
                return o;
            }

            // normal map texture from shader properties
            sampler2D _NormalMap;
            sampler2D _MainTex;
            sampler2D _HeightMap;
            uniform float _MaxHeight;
            uniform float _StepLength;
            uniform float4 _AmbientLight;
            uniform int _MaxStepCount;
            
            float3x3 tspaceToWorldMat;
            float3x3 worldToTspaceMat;

            float getHeight(float2 uv) 
            {
                return _MaxHeight * tex2Dlod(_HeightMap, float4(uv, 0, 0));
            }
            
            float3 tspaceToWorld(float3 tVec)
            {
                return mul(tspaceToWorldMat, tVec);
            }
            
            float3 worldToTspace(float3 worldVec)
            {
                return mul(worldToTspaceMat, worldVec);
            }
            
            // returns false on failure
            bool parallaxOcclusionMapping(float2 startUV, float3 tViewDir, out float2 outUV, out float outDepthDif) 
            {                
                if (getHeight(startUV) == _MaxHeight) {
                    outUV = startUV;
                    outDepthDif = 0;
                    return true;
                }

                float3 step = tViewDir * _StepLength;
                float3 startTPos = float3(startUV, _MaxHeight);
                float3 prevTPos = startTPos;
                float3 curTPos = startTPos;
                int stepCount;

                for (stepCount = 0; stepCount < _MaxStepCount && getHeight(curTPos.xy) < curTPos.z; stepCount++) {
                    prevTPos = curTPos;
                    curTPos += step;
                }
                
                if (getHeight(curTPos.xy) < curTPos.z) {
                    return false;
                }
                
                float prevHightDif = -(getHeight(prevTPos.xy) - prevTPos.z);
                float curHightDif = getHeight(curTPos.xy) - curTPos.z;
                float mid = prevHightDif / (prevHightDif + curHightDif);
                curTPos = prevTPos + (curTPos - prevTPos) * mid;

                outUV = curTPos.xy;
                outDepthDif = length(tspaceToWorld(curTPos - startTPos));
                return true;
            }
        
            void frag (in v2f i, out half4 outColor : COLOR, out float outDepth : DEPTH)
            {
                tspaceToWorldMat = float3x3(i.tspace0, i.tspace1, i.tspace2);
                worldToTspaceMat = transpose(tspaceToWorldMat);

                float dx = ddx(i.uv);
                float dy = ddy(i.uv);

                float3 worldViewDir = normalize(i.worldPos.xyz - _WorldSpaceCameraPos.xyz);
                float3 tViewDir = normalize(mul(worldToTspaceMat, worldViewDir));

                // step POM
                float2 uv;
                float depthDif;
                if (!parallaxOcclusionMapping(i.uv, tViewDir, uv, depthDif)) {
                    outColor = half4(0, 0, 0, 0);
                    // modify depth to simulate transparence
                    outDepth = 2;
                    return;
                }  
                //uv = i.uv + (tViewDir.xy / (-tViewDir.z) * (_MaxHeight - getHeight(i.uv)));
                
                // normal mapping
                half3 tnormal = UnpackNormal(tex2D(_NormalMap, uv, dx, dy));
                half3 worldNormal = normalize(mul(tspaceToWorldMat, tnormal));
                //half3 worldNormal = float3(0, 1, 0);
                
                // soft self-shadowing
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                float shadow = 0;
                {
                    float maxShadow = max(1, 0.004 / _StepLength);
                    float3 tLightDir = normalize(mul(worldToTspaceMat, worldLightDir));
                    float3 step = tLightDir * _StepLength;
                    float3 curTPos = float3(uv, getHeight(uv));
                    if (tLightDir.z > 0) {
                        for (int stepCount = 0; stepCount < _MaxStepCount && curTPos.z < _MaxHeight; stepCount++) {
                            shadow += max(0, getHeight(curTPos.xy) - curTPos.z);
                            curTPos += step;
                        }                        
                    } else {
                        shadow = maxShadow;
                    }
                    shadow /= _MaxHeight;
                    shadow /= maxShadow;
                }

                // compute diffuse lightning
                half cosTheta = max(0, dot(worldNormal, worldLightDir));
                half3 diffuseLight = cosTheta * _LightColor0 * max(0, 1 - shadow);

                // return resulting color
                float3 texColor = tex2D(_MainTex, uv, dx, dy);
                outColor = half4((diffuseLight + _AmbientLight) * texColor, 0);
                outDepth = LinearEyeDepthToOutDepth(LinearEyeDepth(i.clip.z) + depthDif);
            }
            ENDCG
        }
    }
}
