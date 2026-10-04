#version 450

/*
    NTSC-ULTIMATE (Hue, Fidelity, Sat & Black Build - Backported to 110)
    - Feature: Integrated Saturation, Black Level, Resolution, and Hue Control.
    - Feature: Integrated Signal RF Grain (Smart Bypass).
    - Fix: Separated Artifact calculation from Chroma Bleed.
    - Optimization: Column-Major Matrix for legacy GLSL support.
    - Converted to Vulkan/Slang (#version 450)
*/

// --- INTEGRATED PARAMETERS ---
#pragma parameter SATURATION "NTSC: Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "NTSC: Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_res "NTSC: Resolution Scale" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC: Color Hue Shift" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_sharp "NTSC: Sharpness Boost" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC: Edge Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC: Artifact Intensity" 0.0 0.0 1.0 0.05
#pragma parameter sig_noise "Analog: Signal RF Grain" 0.04 0.0 0.5 0.01

// --- ORIGINAL PARAMETERS ---
#pragma parameter Tuning_Sharp "Composite Sharp" 0.0 -30.0 1.0 0.05
#pragma parameter Tuning_Bleed "Composite Bleed" 0.5 0.0 1.0 0.05
#pragma parameter Tuning_Artifacts "Composite Artifacts" 0.5 0.0 1.0 0.05
#pragma parameter NTSCLerp "NTSC Artifacts Mode" 1.0 0.0 1.0 1.0
#pragma parameter NTSCArtifactScale "NTSC Artifact Scale" 255.0 0.0 1000.0 5.0
#pragma parameter animate_artifacts "Animate NTSC Artifacts" 1.0 0.0 1.0 1.0
#pragma parameter Crawl_Speed "NTSC Crawl Speed" 0.10 -2.0 2.0 0.01
#pragma parameter NTSC_Tilt "NTSC Texture Tilt" 0.0 -3.14 3.14 0.1

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float SATURATION;
    float BLACK_LEVEL;
    float ntsc_res;
    float ntsc_hue;
    float ntsc_sharp;
    float fring;
    float afacts;
    float sig_noise;
    float Tuning_Sharp;
    float Tuning_Bleed;
    float Tuning_Artifacts;
    float NTSCLerp;
    float NTSCArtifactScale;
    float animate_artifacts;
    float Crawl_Speed;
    float NTSC_Tilt;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D NTSCArtifactSampler2; 

// YIQ Matrices
const mat3 RGB_to_YIQ = mat3(0.299, 0.5959, 0.2115, 0.587, -0.2746, -0.5227, 0.114, -0.3213, 0.3112);
const mat3 YIQ_to_RGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

float Brightness(vec3 InVal) { 
    return dot(InVal, vec3(0.299, 0.587, 0.114)); 
}

float hash(vec2 co) { 
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); 
}

void main()
{
    // [1] Geometry & Resolution
    float res_mod = 1.0 - (params.ntsc_res * 0.5);
    vec2 SourceSizeXY = params.SourceSize.xy;
    vec2 invSize = 1.0 / SourceSizeXY;
    vec2 resDx = vec2(invSize.x * res_mod, 0.0);
    
    vec3 cur_raw  = texture(Source, vTexCoord).rgb;
    vec3 Cur_L    = texture(Source, vTexCoord - resDx).rgb;
    vec3 Cur_R    = texture(Source, vTexCoord + resDx).rgb;

    // [2] Calculate NTSC Artifacts
    float time_offset = float(params.FrameCount) * params.Crawl_Speed * 0.01; 
    vec2 scanuv = (vTexCoord * SourceSizeXY / params.NTSCArtifactScale);
    scanuv.x += time_offset;
    
    float cosA = cos(params.NTSC_Tilt); 
    float sinA = sin(params.NTSC_Tilt);
    scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
    scanuv = fract(scanuv);

    vec4 art_a = texture(NTSCArtifactSampler2, scanuv);
    vec4 art_b = texture(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y)); 
    float lerpfactor = (params.animate_artifacts > 0.5) ? mod(float(params.FrameCount), 2.0) : params.NTSCLerp;
    vec3 NTSCArtifact = mix(art_a.rgb, art_b.rgb, 1.0 - lerpfactor);

    float total_artifacts = params.Tuning_Artifacts + (params.afacts * 0.5);
    vec3 res = cur_raw + ((Cur_L - cur_raw) + (Cur_R - cur_raw)) * NTSCArtifact * total_artifacts;

    // [3] Apply Chroma Bleed, Fringing, Hue & Saturation
    float total_bleed = params.Tuning_Bleed + (params.fring * 0.5);
    vec3 c_m = res * RGB_to_YIQ;
    
    vec2 bleedDx = resDx * (2.0 + total_bleed * 3.0);
    vec3 c_l = texture(Source, vTexCoord - bleedDx).rgb * RGB_to_YIQ;
    vec3 c_r = texture(Source, vTexCoord + bleedDx).rgb * RGB_to_YIQ;
    
    vec2 spread_chroma = mix(c_m.yz, (c_l.yz + c_r.yz) * 0.5, total_bleed);

    float hue_angle = params.ntsc_hue * 6.28318;
    float cosH = cos(hue_angle);
    float sinH = sin(hue_angle);
    
    vec2 rotated_chroma;
    // Rotate Hue and apply Global Saturation
    rotated_chroma.x = (spread_chroma.x * cosH - spread_chroma.y * sinH) * params.SATURATION;
    rotated_chroma.y = (spread_chroma.x * sinH + spread_chroma.y * cosH) * params.SATURATION;

    res = vec3(c_m.x, rotated_chroma) * YIQ_to_RGB;

    // [4] Sharpness & Fidelity
    float bM = Brightness(res);
    float bL = Brightness(Cur_L);
    float bR = Brightness(Cur_R);
    
    float total_sharp = params.Tuning_Sharp + (params.ntsc_sharp * 0.5);
    float sharp = (bM * 2.0 - bL - bR) * total_sharp;
    res = res + sharp;

    // [5] Analog Effects (Smart Bypass)
    if (params.sig_noise > 0.0) {
        res += (hash(vTexCoord + vec2(float(params.FrameCount) * 0.01)) - 0.5) * params.sig_noise;
    }

    // [6] Final Black Level Adjustment
    res = mix(vec3(params.BLACK_LEVEL), vec3(1.0), res);

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}