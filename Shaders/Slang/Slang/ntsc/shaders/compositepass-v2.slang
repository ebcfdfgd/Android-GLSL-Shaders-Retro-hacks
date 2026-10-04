#version 450

// --- NTSC-ULTIMATE-PERSISTENCE (Brightness Build + RF Grain) ---
// - Cleaned: Removed Black Level, Resolution, and Sharpness controls.
// - Added: Global Signal Brightness control.
// - Converted to #version 450 (Vulkan/Slang)

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_hue "Color Hue Shift" 0.0 -0.5 0.5 0.01
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 10.2 0.01

// --- ORIGINAL PARAMETERS ---
#pragma parameter Tuning_Sharp "Composite Sharp" 0.0 -30.0 1.0 0.05
#pragma parameter Tuning_Persistence_R "Red Persistence" 0.075 0.0 1.0 0.01
#pragma parameter Tuning_Persistence_G "Green Persistence" 0.05 0.0 1.0 0.01
#pragma parameter Tuning_Persistence_B "Blue Persistence" 0.05 0.0 1.0 0.01
#pragma parameter Tuning_Bleed "Composite Bleed" 0.5 0.0 1.0 0.05
#pragma parameter Tuning_Artifacts "Composite Artifacts" 0.5 0.0 1.0 0.05
#pragma parameter NTSCLerp "NTSC Artifacts" 1.0 0.0 1.0 1.0
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
    float NTSC_BRIGHTNESS;
    float ntsc_hue;
    float SATURATION;
    float fring;
    float afacts;
    float sig_noise;
    float Tuning_Sharp;
    float Tuning_Persistence_R;
    float Tuning_Persistence_G;
    float Tuning_Persistence_B;
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

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

// Texture Bindings
layout(set = 0, binding = 2) uniform sampler2D Source;
// Note: You must ensure NTSCArtifactSampler2 is provided by your preset (.slangp)
layout(set = 0, binding = 3) uniform sampler2D NTSCArtifactSampler2;

// Slang Standard History Buffers
layout(set = 0, binding = 4) uniform sampler2D OriginalHistory1;
layout(set = 0, binding = 5) uniform sampler2D OriginalHistory2;
layout(set = 0, binding = 6) uniform sampler2D OriginalHistory4;

const mat3 RGB_to_YIQ = mat3(0.299, 0.587, 0.114, 0.5959, -0.2746, -0.3213, 0.2115, -0.5227, 0.3112);
const mat3 YIQ_to_RGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.106, 1.703);

float hash(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float Brightness(vec3 InVal) {
    return dot(InVal, vec3(0.299, 0.587, 0.114));
}

void main()
{
    vec2 invSize = params.SourceSize.zw; 
    vec2 dx = vec2(invSize.x, 0.0);
    
    vec3 cur_raw = texture(Source, vTexCoord).rgb;
    vec3 Cur_L = texture(Source, vTexCoord - dx).rgb;
    vec3 Cur_R = texture(Source, vTexCoord + dx).rgb;

    float time_offset = float(params.FrameCount) * params.Crawl_Speed * 0.01; 
    vec2 scanuv = (vTexCoord * params.SourceSize.xy / params.NTSCArtifactScale);
    scanuv.x += time_offset;
    
    float cosA = cos(params.NTSC_Tilt); 
    float sinA = sin(params.NTSC_Tilt);
    scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
    scanuv = fract(scanuv);

    vec4 art_a = texture(NTSCArtifactSampler2, scanuv);
    vec4 art_b = texture(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y));
    float lerpfactor = (params.animate_artifacts > 0.5) ? mod(float(params.FrameCount), 2.0) : params.NTSCLerp;
    vec3 NTSCArtifact = mix(art_a.rgb, art_b.rgb, 1.0 - lerpfactor);

    float total_arts = params.Tuning_Artifacts + (params.afacts * 0.4);
    vec3 res = cur_raw + ((Cur_L - cur_raw) + (Cur_R - cur_raw)) * NTSCArtifact * total_arts;

    float total_bleed = params.Tuning_Bleed + (params.fring * 0.5);
    vec3 c_m = res * RGB_to_YIQ;
    
    vec2 bleedDx = dx * (2.0 + total_bleed * 3.0);
    vec3 c_l = texture(Source, vTexCoord - bleedDx).rgb * RGB_to_YIQ;
    vec3 c_r = texture(Source, vTexCoord + bleedDx).rgb * RGB_to_YIQ;
    
    vec2 spread_chroma = mix(c_m.yz, (c_l.yz + c_r.yz) * 0.5, total_bleed);

    float hue_angle = params.ntsc_hue * 6.28318;
    float cosH = cos(hue_angle) * params.SATURATION;
    float sinH = sin(hue_angle) * params.SATURATION;
    vec2 rotated_chroma;
    rotated_chroma.x = spread_chroma.x * cosH - spread_chroma.y * sinH;
    rotated_chroma.y = spread_chroma.x * sinH + spread_chroma.y * cosH;

    res = vec3(c_m.x, rotated_chroma) * YIQ_to_RGB;

    float bM = Brightness(res);
    float bL = Brightness(Cur_L);
    float bR = Brightness(Cur_R);
    float sharp = (bM * 2.0 - bL - bR) * params.Tuning_Sharp;
    res = clamp(res + sharp, 0.0, 1.0);

    if (params.sig_noise > 0.0) res += (hash(vTexCoord + float(params.FrameCount) * 0.01) - 0.5) * params.sig_noise;

    // Using Standard Slang History Buffers
    vec3 p1 = texture(OriginalHistory1, vTexCoord).rgb;
    vec3 p2 = texture(OriginalHistory2, vTexCoord).rgb;
    vec3 p4 = texture(OriginalHistory4, vTexCoord).rgb;
    vec3 Prev_Avg = (p1 + p2 + p4) * 0.333;

    vec3 persist_color = vec3(params.Tuning_Persistence_R, params.Tuning_Persistence_G, params.Tuning_Persistence_B);
    res = max(res, persist_color * Prev_Avg * (5.0 / (1.0 + total_bleed * 0.2)));

    // --- APPLY BRIGHTNESS ---
    res *= params.NTSC_BRIGHTNESS;

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}