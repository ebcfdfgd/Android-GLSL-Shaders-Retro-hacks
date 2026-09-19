/*
    NTSC-ULTIMATE-PERSISTENCE (Hue, Sharp, Sat & Black Build - 110)
    - Integrated: Resolution, Hue Shift, Sharpness, Fringing, Artifacts.
    - Optimized: Combined Bleed, Persistence, YIQ Color Rotation.
    - Added: Smart Bypass RF Grain (Zero = OFF).
    - Added: Global Saturation & Final Black Level control.
*/

// --- INTEGRATED PARAMETERS ---
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_res "Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_hue "Color Hue Shift" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_sharp "Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter sig_noise "Analog: Signal RF Grain" 0.04 0.0 0.5 0.01

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

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform int FrameCount;
uniform vec2 TextureSize;
uniform sampler2D Texture;
uniform sampler2D NTSCArtifactSampler2; 
uniform sampler2D PrevTexture;
uniform sampler2D Prev2Texture;
uniform sampler2D Prev4Texture;

#ifdef PARAMETER_UNIFORM
uniform float SATURATION, BLACK_LEVEL, ntsc_res, ntsc_hue, ntsc_sharp, fring, afacts;
uniform float Tuning_Sharp, Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B;
uniform float Tuning_Bleed, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
uniform float sig_noise;
#endif

const mat3 RGB_to_YIQ = mat3(0.299, 0.5959, 0.2115, 0.587, -0.2746, -0.5227, 0.114, -0.3213, 0.3112);
const mat3 YIQ_to_RGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

float Brightness(vec3 InVal) { 
    return dot(InVal, vec3(0.299, 0.587, 0.114)); 
}

float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main()
{
    float res_mod = 1.0 - (ntsc_res * 0.5);
    vec2 SourceSize = TextureSize;
    vec2 invSize = vec2(res_mod / SourceSize.x, 1.0 / SourceSize.y);
    
    float time_offset = float(FrameCount) * Crawl_Speed * 0.01; 
    vec2 scanuv = (TEX0 * SourceSize / NTSCArtifactScale);
    scanuv.x += time_offset;
    
    float cosA = cos(NTSC_Tilt); 
    float sinA = sin(NTSC_Tilt);
    scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
    scanuv = fract(scanuv);

    vec4 art_a = texture2D(NTSCArtifactSampler2, scanuv);
    vec4 art_b = texture2D(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y));
    float lerpfactor = (animate_artifacts > 0.5) ? mod(float(FrameCount), 2.0) : NTSCLerp;
    vec3 NTSCArtifact = mix(art_a.rgb, art_b.rgb, 1.0 - lerpfactor);

    float fring_step = 1.0 + fring;
    vec2 dx = vec2(invSize.x * fring_step, 0.0);
    vec3 Cur_L = texture2D(Texture, TEX0 - dx).rgb;
    vec3 Cur_M = texture2D(Texture, TEX0).rgb;
    vec3 Cur_R = texture2D(Texture, TEX0 + dx).rgb;

    float total_art = Tuning_Artifacts + (afacts * 0.4);
    vec3 res = Cur_M + ((Cur_L - Cur_M) + (Cur_R - Cur_M)) * NTSCArtifact * total_art;
    
    // --- CHROMA PROCESSING (HUE & SATURATION) ---
    vec3 yiq = res * RGB_to_YIQ;
    float hue_angle = ntsc_hue * 6.28318;
    float cosH = cos(hue_angle);
    float sinH = sin(hue_angle);
    
    vec2 rotated_IQ;
    // Rotate Hue and Apply Saturation to I and Q components
    rotated_IQ.x = (yiq.y * cosH - yiq.z * sinH) * SATURATION;
    rotated_IQ.y = (yiq.y * sinH + yiq.z * cosH) * SATURATION;
    
    res = vec3(yiq.x, rotated_IQ) * YIQ_to_RGB;

    // --- LUMA SHARPENING ---
    float bM = Brightness(res);
    float bL = Brightness(Cur_L);
    float bR = Brightness(Cur_R);
    float total_sharp = Tuning_Sharp + (ntsc_sharp * 0.2);
    float sharp = (bM * 2.0 - bL - bR) * total_sharp;
    
    res = clamp(res + (sharp * mix(vec3(1.0), NTSCArtifact, total_art)), 0.0, 1.0);

    // --- PERSISTENCE ENGINE ---
    vec3 p1 = texture2D(PrevTexture, TEX0).rgb;
    vec3 p2 = texture2D(Prev2Texture, TEX0).rgb;
    vec3 p4 = texture2D(Prev4Texture, TEX0).rgb;
    vec3 Prev_Avg = (p1 + p2 + p4) * 0.333;

    vec3 persist_color = vec3(Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B);
    res = max(res, persist_color * Prev_Avg * (10.0 / (1.0 + Tuning_Bleed)));

    // --- ANALOG RF NOISE ---
    if (sig_noise > 0.0) {
        res += (hash(TEX0 + vec2(float(FrameCount) * 0.01)) - 0.5) * sig_noise;
    }

    // --- FINAL BLACK LEVEL & CLAMP ---
    res = mix(vec3(BLACK_LEVEL), vec3(1.0), res);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
} 
#endif