// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "0_Custom/Diffuse"
{
    Properties
    {
        _DiffuseColor ("DiffuseColor", Color) = (1, 1, 1, 1)
        _DiffusePower ("DiffusePower", Float) = 1
        _SpecularPower ("SpecularPower", Float) = 1
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
                float3 pos : TEXCOORD1;
                fixed3 normal : NORMAL;
            };

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
            
            // See: https://stackoverflow.com/questions/11132681/what-is-a-formula-to-get-a-vector-perpendicular-to-another-vector
            float3 GetOrthogonal(float3 vec)
            {
                float scale = abs(vec.x) + abs(vec.y) + abs(vec.z);

                if (scale == 0) {
                    return float3(0, 0, 0);
                }
                
                float x = vec.x / scale;
                float y = vec.y / scale;
                float z = vec.z / scale;
                
                if (abs(x) > abs(y)) {
                    return float3(z, 0, -x);
                } else {
                    return float3(0, z, -y);
                }
            }
            
            float HashToFloat(uint hash)
            {
                return float(hash) / 4294967295.0; // 2^32-1;
            }
            
            // see: https://en.wikipedia.org/wiki/Rodrigues'_rotation_formula
            float3 Rotate(float3 v, float3 axis, float cos)
            {
                if (cos == 1) {
                    return v;
                }
                axis = normalize(axis);
                float sin = sqrt(1 - cos * cos);
                return v * cos + cross(axis, v) * sin + axis * dot(axis, v) * (1 - cos);
            }
            
            float4 _DiffuseColor;
            float _DiffusePower;
            float _SpecularPower;

            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                const int sampleCount = 1000;
                const float PI = 3.14159;
                const float3 yAxis = float3(0, 1, 0);
                
                const float3 viewDirection = normalize(UnityWorldSpaceViewDir(i.pos));
                const float3 reflectDirection = reflect(-viewDirection, i.normal);
                const float powerNorm = _DiffusePower + _SpecularPower; 
                const float diffusePower = _DiffusePower / powerNorm;
                const float specularPower = _SpecularPower / powerNorm;
            
                float3 res = float3(0, 0, 0);
                uint seed = 42424217;
                float cosExpected = 0;
                
                if (diffusePower > 0) {
                    for (int j = 0; j < sampleCount; j++) {
                        float3 lightDirection;
                        
                        seed = Hash(seed);
                        float sphereY = HashToFloat(seed) * (1 - specularPower) + specularPower;
                        seed = Hash(seed);
                        float sphereAng = HashToFloat(seed) * 2 * PI;
                        float orthLen = sqrt(1 - sphereY * sphereY);
                        lightDirection = float3(cos(sphereAng) * orthLen, sphereY, sin(sphereAng) * orthLen);
                    
                        // Rotate the vector to a random direction and then to the desired direction.
                        // This helps to avoid discontinuity points on the sphere.
                        const float3 targetDirection = i.normal;
                        seed = Hash(seed);
                        float rdX = seed;
                        seed = Hash(seed);
                        float rdY = seed;
                        seed = Hash(seed);
                        float rdZ = seed;
                        const float3 randomDirection = normalize(float3(rdX, rdY, rdZ));
                        lightDirection = Rotate(lightDirection, cross(yAxis, randomDirection), dot(yAxis, randomDirection));
                        lightDirection = Rotate(lightDirection, cross(randomDirection, targetDirection), dot(randomDirection, targetDirection));
                        // lightDirection = Rotate(lightDirection, cross(yAxis, targetDirection), dot(yAxis, targetDirection));
                        
                        half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, lightDirection, 0);
                        half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);
                        
                        float cos = dot(i.normal, lightDirection);
                        cosExpected += cos / sampleCount;
                        res += diffusePower * _DiffuseColor * skyColor * cos / sampleCount;
                    }

                    res /= cosExpected;
                }
                
                if (specularPower > 0) {
                    for (int j = 0; j < sampleCount; j++) {
                        float3 lightDirection;

                        seed = Hash(seed);
                        float sphereY = HashToFloat(seed) * (1 - specularPower) + specularPower;
                        seed = Hash(seed);
                        float sphereAng = HashToFloat(seed) * 2 * PI;
                        float orthLen = sqrt(1 - sphereY * sphereY);
                        lightDirection = float3(cos(sphereAng) * orthLen, sphereY, sin(sphereAng) * orthLen);
                        
                        // Rotate the vector to a random direction and then to the desired direction.
                        // This helps to avoid discontinuity points on the sphere.
                        const float3 targetDirection = reflectDirection;
                        seed = Hash(seed);
                        float rdX = seed;
                        seed = Hash(seed);
                        float rdY = seed;
                        seed = Hash(seed);
                        float rdZ = seed;
                        const float3 randomDirection = normalize(float3(rdX, rdY, rdZ));
                        lightDirection = Rotate(lightDirection, cross(yAxis, randomDirection), dot(yAxis, randomDirection));
                        lightDirection = Rotate(lightDirection, cross(randomDirection, targetDirection), dot(randomDirection, targetDirection));
                        // lightDirection = Rotate(lightDirection, cross(yAxis, targetDirection), dot(yAxis, targetDirection));

                        if (dot(lightDirection, i.normal) < 0) {
                            lightDirection = reflectDirection;
                        }
                        
                        half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, lightDirection, 0);
                        half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);
    
                        res += specularPower * skyColor / sampleCount;
                    }
                }

                return half4(res, 1);
            }
            ENDCG
        }
    }
}
