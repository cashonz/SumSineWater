Shader "BlitWithMaterial"
{
    Properties
    {
    }
   SubShader
   {
       Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
       ZWrite Off Cull Off
       Pass
       {
           Name "BlitWithMaterialPass"

           HLSLPROGRAM
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           //This already defines Varyings, _BlitTexture and _BlitMipLevel
           #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
           //Makes us able to access depth texture through SampleSceneDepth(UV)
           //and contains texture definitions/sampler for _CameraDepthTexture 
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl" 

           #pragma vertex Vert
           #pragma fragment Frag

           float _FogStrength;
           float4 _FogColor;

            float4 Mix(float4 x, float4 y, float a)
            {
                return x * (1-a) + y * a;
            }

            float CalcFogFactor(float z)
            {
                return exp(-_FogStrength * z);
            }

            float3 ReconstructWorldPosition(float2 uv, float rawDepth, float4x4 invViewProj)
            {
                // Transform depth from [0,1] to clip space [-1,1]
                float4 clipPos = float4(uv * 2 - 1, rawDepth * 2 - 1, 1.0);
                
                // Transform to world space
                float4 worldPos = mul(invViewProj, clipPos);
                worldPos /= worldPos.w;
                
                return worldPos.xyz;
            }

            // Out frag function takes as input a struct that contains the screen space coordinate we are going to use to sample our texture. It also writes to SV_Target0, this has to match the index set in the UseTextureFragment(sourceTexture, 0, …) we defined in our render pass script.   
            float4 Frag(Varyings IN) : SV_Target
            {

               // sample the texture using the SAMPLE_TEXTURE2D_X_LOD
               float2 UV = IN.texcoord.xy;
               half4 color = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, UV, _BlitMipLevel);

               #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    // Adjust Z to match NDC for OpenGL ([-1, 1])
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif

                depth = depth * _FogStrength;

                float f = saturate(CalcFogFactor(depth));

                // Modify the sampled color
                return color * (1-f) + _FogColor * f;
           }

           ENDHLSL
       }
   }
}