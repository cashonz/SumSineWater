Shader "Unlit/SumSineWater"
{
    Properties
    {
    }
    SubShader
    {
        Tags { 
            "RenderType"="Opaque" 
        }

        Pass
        {
            ZWrite On

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature USE_FBM
            #pragma shader_feature SEPARATE_DIFFUSE

            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION; //Object space
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION; //screen space
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };
            struct wave
            {
                float amplitude;
                float phase;
                float frequency;
                float2 direction;
            };

            StructuredBuffer<wave> _Waves;

            float4 _Color;
            float4 _DiffuseCol;
            float _Specular;
            float _Diffuse;
            int _WaveCount;
            float _Frequency;
            float _Phase;
            float _Lacunarity;
            float _Persistance;
            float _PhaseModifier;
            float _Drag;
            int _Octaves;
            float _VertHeightMultiplier;
            float _WavePeak;
            float _WavePeakOffset;

            float CalculateHeight(float2 worldPos, wave w)
            {
                float x = dot(w.direction, worldPos) * w.frequency + _Time.y * w.phase;
                return w.amplitude * exp(sin(x) - 1);
            }

            float2 CalculateNormal(float2 worldPos, wave w)
            {
                float x = dot(w.direction, worldPos) * w.frequency + _Time.y * w.phase;
                float h = w.amplitude * exp(sin(x) - 1);
                return w.frequency * w.direction * w.amplitude * cos(x);
            }

            float CalculateHeightFBM(float2 worldPos, float a, float2 d, float f, float w)
            {
                float x = dot(d, worldPos) * f + _Time.y * w;
                return a * exp(_WavePeak * sin(x) - _WavePeakOffset);
            }

            float CalculateNormalFBM(float2 worldPos, float a, float2 d, float f, float w)
            {
                float x = dot(d, worldPos) * f + _Time.y * w;
                float h = a * exp(_WavePeak * sin(x) - _WavePeakOffset);
                return f * d * a * h * cos(x);
            }

            float FBM(float3 v)
            {
                float f = _Frequency;
                float a = 1;
                float w = _Phase;
                float Lacunarity = _Lacunarity;
                float persistance = _Persistance;
                float wMod = _PhaseModifier;
                int octaves = _Octaves;
                float dirSeed = 0;
                float aSum = 0;
                float valSum = 0;
                float3 p = v;
                float h = 0.0f;
                float2 n = 0.0f;

                for(int i = 0; i < octaves; i++)
                {
                    float2 d = normalize(float2(sin(dirSeed), cos(dirSeed)));
                    h = CalculateHeightFBM(p.xz, a, d, f, w);
                    n = CalculateNormalFBM(p.xz, a, d, f, w);
                    
                    p.xz += n * a * _Drag;
                    aSum += a;
                    valSum += h * a;
                    f *= Lacunarity;
                    a *= persistance;
                    w *= wMod;
                    dirSeed += 53;
                }

                return (valSum / aSum) * _VertHeightMultiplier;

            }

            float2 FBMNormals(float3 v)
            {
                float f = _Frequency;
                float a = 1;
                float w = _Phase;
                float Lacunarity = _Lacunarity;
                float persistance = _Persistance;
                float wMod = _PhaseModifier;
                int octaves = _Octaves;
                float dirSeed = 0;
                float aSum = 0;

                float2 n = 0.0f;

                for(int i = 0; i < octaves; i++)
                {
                    float2 d = normalize(float2(cos(dirSeed), sin(dirSeed)));
                    n += CalculateNormalFBM(v.xz, a, d, f, w);

                    aSum += a;
                    f *= Lacunarity;
                    a *= persistance;
                    w *= wMod;
                    dirSeed += 53;
                }

                return (n / aSum) * _VertHeightMultiplier;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                float h = 0.0f;
                float2 n = 0.0f;

                #ifdef USE_FBM
                
                h = FBM(o.worldPos);
                float4 newPos = v.vertex + float4(0.0f, 0.0f, h, 0.0f);
				o.vertex = UnityObjectToClipPos(newPos);
                o.worldPos = mul(unity_ObjectToWorld, newPos);

                n = FBMNormals(o.worldPos);

                #else
                for(int i = 0; i < _WaveCount; i++)
                {
                    h += CalculateHeight(o.worldPos.xz, _Waves[i]);
                }

                float4 newPos = v.vertex + float4(0.0f, 0.0f, h, 0.0f);
				o.vertex = UnityObjectToClipPos(newPos);

                o.worldPos = mul(unity_ObjectToWorld, newPos);

                for(int i = 0; i < _WaveCount; i++)
                {
                    n += CalculateNormal(o.worldPos.xz, _Waves[i]);
                }

                #endif

                o.normal = normalize(float3(-n.x, 1.0f, -n.y));

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                #ifdef SEPARATE_DIFFUSE
                float3 diffuseCol = _DiffuseCol * _Diffuse;
                #else
                float3 diffuseCol = _Color * _Diffuse;
                #endif

                float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 halfwayDir = normalize(lightDirection + viewDirection);

                float3 diffuse = max(dot(lightDirection, i.normal), 0);
                float3 specular = pow(max(dot(halfwayDir, i.normal), 0), _Specular);
                float3 output = _Color + diffuse * diffuseCol + specular * _LightColor0;
                return float4(output, 1.0f);
            }
            ENDCG
        }
    }
}
