#version 110

/*
    NTSC-ULTIMATE-PERSISTENCE (Hue & Sharp Build + Noise/Jailbars)
    - Integrated: Resolution, Hue Shift, Sharpness, Fringing, Artifacts.
    - Optimized: Combined Bleed, Persistence and YIQ Color Rotation.
    - Added: Analog Noise & MD Vertical Jailbars.
*/

// --- INTEGRATED PARAMETERS ---
#pragma parameter ntsc_res "Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_hue "Color Hue Shift" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_sharp "Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter NOISE_STR "Analog Noise Intensity" 0.04 0.0 2.0 0.01
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1

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
uniform float ntsc_res, ntsc_hue, ntsc_sharp, fring, afacts;
uniform float Tuning_Sharp, Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B;
uniform float Tuning_Bleed, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
uniform float NOISE_STR, jail_str, jail_width;
#endif

const mat3 RGB_to_YIQ = mat3(0.299, 0.587, 0.114, 0.5959, -0.2746, -0.3213, 0.2115, -0.5227, 0.3112);
const mat3 YIQ_to_RGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.106, 1.703);

float Brightness(vec3 InVal) { 
    return dot(InVal, vec3(0.299, 0.587, 0.114)); 
}

float fast_rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.98, 78.23))) * 437.5);
}

void main()
{
    float res_step = 1.0 - (ntsc_res * 0.5);
    vec2 SourceSize = TextureSize;
    vec2 invSize = vec2(res_step / SourceSize.x, 1.0 / SourceSize.y);
    vec2 dx = vec2(invSize.x, 0.0);
    
    vec3 cur_raw = texture2D(Texture, TEX0).rgb;
    vec3 Cur_L = texture2D(Texture, TEX0 - dx).rgb;
    vec3 Cur_R = texture2D(Texture, TEX0 + dx).rgb;

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

    float total_arts = Tuning_Artifacts + (afacts * 0.4);
    vec3 res = cur_raw + ((Cur_L - cur_raw) + (Cur_R - cur_raw)) * NTSCArtifact * total_arts;

    float total_bleed = Tuning_Bleed + (fring * 0.5);
    vec3 c_m = res * RGB_to_YIQ;
    
    vec2 bleedDx = dx * (2.0 + total_bleed * 3.0);
    vec3 c_l = texture2D(Texture, TEX0 - bleedDx).rgb * RGB_to_YIQ;
    vec3 c_r = texture2D(Texture, TEX0 + bleedDx).rgb * RGB_to_YIQ;
    
    vec2 spread_chroma = mix(c_m.yz, (c_l.yz + c_r.yz) * 0.5, total_bleed);

    float hue_angle = ntsc_hue * 6.28318;
    float cosH = cos(hue_angle);
    float sinH = sin(hue_angle);
    vec2 rotated_chroma;
    rotated_chroma.x = spread_chroma.x * cosH - spread_chroma.y * sinH;
    rotated_chroma.y = spread_chroma.x * sinH + spread_chroma.y * cosH;

    res = vec3(c_m.x, rotated_chroma) * YIQ_to_RGB;

    float bM = Brightness(res);
    float bL = Brightness(Cur_L);
    float bR = Brightness(Cur_R);
    float total_sharp = Tuning_Sharp + (ntsc_sharp * 0.3);
    float sharp = (bM * 2.0 - bL - bR) * total_sharp;
    res = clamp(res + sharp, 0.0, 1.0);

    // --- ARTIFACTS: JAILBARS & NOISE ---
    if (jail_str > 0.0) res += sin(TEX0.x * TextureSize.x * jail_width) * jail_str * 0.02;
    if (NOISE_STR > 0.0) res += (fast_rand(TEX0 + float(FrameCount) * 0.01) - 0.5) * NOISE_STR;

    vec3 p1 = texture2D(PrevTexture, TEX0).rgb;
    vec3 p2 = texture2D(Prev2Texture, TEX0).rgb;
    vec3 p4 = texture2D(Prev4Texture, TEX0).rgb;
    vec3 Prev_Avg = (p1 + p2 + p4) * 0.333;

    vec3 persist_color = vec3(Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B);
    res = max(res, persist_color * Prev_Avg * (5.0 / (1.0 + total_bleed * 0.2)));

    gl_FragColor = vec4(res, 1.0);
} 
#endif