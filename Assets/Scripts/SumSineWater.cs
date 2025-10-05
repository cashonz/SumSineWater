using UnityEngine;
using System.Collections;
using static System.Runtime.InteropServices.Marshal;

/*
Move setting of parameters in here.
Create buffer to be sent to the GPU containing waves structs.
Update shaderparameters in Update()
implement generation of random wave parameters within thresholds for each wave
*/ 
public class SumSineWater : MonoBehaviour
{
    public Material waterMat;
    public Shader waterShader;
    public Light lightSource;
    [Header("Random Water Parameters")]
    public int waveCount = 64;
    public float meanWaveLength = 0.2f;
    public float waveLengthVariance = 0.1f;
    public float meanAmplitude = 0.1f;
    public float amplitudeVariance = 0.1f;
    public float meanDirection = 0;
    public float directionVariance = 0.5f;
    public float meanSpeed = 1.0f;
    public float speedVariance = 1.0f;
    [Header("FBM Water Parameters")]
    public bool useFBM = false;
    public float frequency;
    public float phase;
    public float lacunarity;
    public float persistance;
    public float phaseModifier;
    public int octaves;
    public float vertHeightMultiplier;
    public float drag;
    public float wavePeak;
    public float wavePeakOffset;

    [Header("Light Parameters")]
    public Color ambientColor;
    public Color diffuseColor;
    public Color lightColor;
    public float lightIntensity = 1.0f;
    public bool separateDiffuse = false;
    public float specularVal;
    public float diffuseVal;
    private Wave[] waves = new Wave[64];
    private ComputeBuffer waveBuffer;

    public struct Wave
    {
        public float amplitude;
        public float phase;
        public float frequency;
        public Vector2 direction;

        public Wave(float waveLength, float amplitude, float directionX, float directionY, float speed)
        {
            this.amplitude = amplitude;
            this.phase = speed * Mathf.Sqrt(9.8f * 2.0f * Mathf.PI / waveLength);
            this.frequency = 2.0f / waveLength;
            this.direction = new Vector2(directionX, directionY);
            this.direction.Normalize();
        }
    }

    void CreateWaveBuffer()
    {
        if (waveBuffer != null) return;

        int stride =  System.Runtime.InteropServices.Marshal.SizeOf(typeof(Wave));
        waveBuffer = new ComputeBuffer(64, stride);
        waterMat.SetBuffer("_Waves", waveBuffer);
    }

    void GenerateWaves()
    {
        float maxWaveLength = meanWaveLength + waveLengthVariance;
        float minWaveLength = meanWaveLength - waveLengthVariance;
        float maxAmplitude = meanAmplitude + amplitudeVariance;
        float minAmplitude = meanAmplitude - amplitudeVariance;
        float maxDirection = meanDirection + directionVariance;
        float minDirection = meanDirection - directionVariance;
        float maxSpeed = meanSpeed + speedVariance;
        float minSpeed = meanSpeed - speedVariance;

        //Generate waves here
        for (int i = 0; i < waveCount; i++)
        {
            float waveLength = UnityEngine.Random.Range(minWaveLength, maxWaveLength);
            float amplitude = UnityEngine.Random.Range(minAmplitude, maxAmplitude);
            float directionX = UnityEngine.Random.Range(minDirection, maxDirection);
            float directionY = UnityEngine.Random.Range(minDirection, maxDirection);
            float speed = UnityEngine.Random.Range(minSpeed, maxSpeed);
            waves[i] = new Wave(waveLength, amplitude, directionX, directionY, speed);
        }

        waveBuffer.SetData(waves);
        waterMat.SetBuffer("_Waves", waveBuffer);
    }
    void OnEnable()
    {
        waterMat.SetInt("_WaveCount", waveCount);
        CreateWaveBuffer();
        GenerateWaves();
    }

    void OnDisable()
    {
        if (waveBuffer != null)
        {
            waveBuffer.Release();
            waveBuffer = null;
        }
    }

    void Update()
    {
        lightSource.color = lightColor;
        lightSource.intensity = lightIntensity;

        //Update material parameters
        waterMat.SetVector("_Color", ambientColor);
        waterMat.SetVector("_DiffuseCol", diffuseColor);
        waterMat.SetFloat("_Specular", specularVal);
        waterMat.SetFloat("_Diffuse", diffuseVal);

        if (useFBM)
        {
            waterMat.EnableKeyword("USE_FBM");
        }
        else
        {
            waterMat.DisableKeyword("USE_FBM");
        }

        if (separateDiffuse)
        {
            waterMat.EnableKeyword("SEPARATE_DIFFUSE");
        }
        else
        {
            waterMat.DisableKeyword("SEPARATE_DIFFUSE");
        }

        waterMat.SetFloat("_Frequency", frequency);
        waterMat.SetFloat("_Phase", phase);
        waterMat.SetFloat("_Lacunarity", lacunarity);
        waterMat.SetFloat("_Persistance", persistance);
        waterMat.SetFloat("_PhaseModifier", phaseModifier);
        waterMat.SetInt("_Octaves", octaves);
        waterMat.SetFloat("_VertHeightMultiplier", vertHeightMultiplier);
        waterMat.SetFloat("_Drag", drag);
        waterMat.SetFloat("_WavePeak", wavePeak);
        waterMat.SetFloat("_WavePeakOffset", wavePeakOffset);
    }
}
