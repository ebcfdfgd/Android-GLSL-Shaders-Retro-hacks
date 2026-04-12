#version 110

/*
    NTSC Shader - Ultra Optimized (Hue & Sharpness Build)
    - Integrated: Resolution scaling, Sharpness, Fringing, Artifacts, and Hue Shift.
    - Performance: 7-Sample efficiency (5 from source, 2 from noise).
    - Logic: Accurate Hue Rotation in YIQ Space without additional fetches.
*/

// --- INTEGRATED PARAMETERS ---
#pragma parameter ntsc_res "NTSC: Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC: Color Hue Shift" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_sharp "NTSC: Sharpness Boost" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC: Edge Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC: Artifact Intensity" 0.0 0.0 1.0 0.05

// --- ORIGINAL TUNING PARAMETERS ---
#pragma parameter Tuning_Sharp "Composite Sharp" 0.0 -30.0 1.0 0.05
#pragma parameter Tuning_Artifacts "Composite Artifacts" 0.5 0.0 1.0 0.05
#pragma parameter NTSCLerp "NTSC Artifacts Lerp" 1.0 0.0 1.0 1.0
#pragma parameter NTSCArtifactScale "NTSC Artifact Scale" 255.0 0.0 1000.0 5.0
#pragma parameter animate_artifacts "Animate NTSC Artifacts" 1.0 0.0 1.0 1.0
#pragma parameter Crawl_Speed "NTSC Crawl Speed" 0.10 -2.0 2.0 0.01
#pragma parameter NTSC_Tilt "NTSC Texture Tilt" 0.0 -3.14 3.14 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform int FrameCount;
uniform vec2 TextureSize;
uniform sampler2D Texture;
uniform sampler2D NTSCArtifactSampler2; 

#ifdef PARAMETER_UNIFORM
uniform float ntsc_res, ntsc_hue, ntsc_sharp, fring, afacts;
uniform float Tuning_Sharp, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
#endif

// مصفوفات تحويل YIQ (تحاكي معالجة التلفاز التماثلي للألوان)
const mat3 RGB_to_YIQ = mat3(0.299, 0.5959, 0.2115, 0.587, -0.2746, -0.5227, 0.114, -0.3213, 0.3112);
const mat3 YIQ_to_RGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

float Brightness(vec3 InVal) { 
    return dot(InVal, vec3(0.299, 0.587, 0.114)); 
}

void main()
{
    // 1. Resolution & Pixel Geometry
    float res_step = 1.0 - (ntsc_res * 0.5);
    vec2 invSize = 1.0 / TextureSize;
    vec2 resInvSize = vec2(invSize.x * res_step, invSize.y);
    float time_offset = float(FrameCount) * Crawl_Speed * 0.01; 

    // 2. Artifacts Mapping (سحبتان من تكتشر الضوضاء)
    vec2 scanuv = (vTexCoord * TextureSize) / NTSCArtifactScale;
    scanuv.x += time_offset;
    
    float cosA = cos(NTSC_Tilt); 
    float sinA = sin(NTSC_Tilt);
    scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
    scanuv = fract(scanuv);

    vec4 art_a = texture2D(NTSCArtifactSampler2, scanuv);
    vec4 art_b = texture2D(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y));
    
    float lerpfactor = (animate_artifacts > 0.5) ? mod(float(FrameCount), 2.0) : NTSCLerp;
    vec3 NTSCArtifact = mix(art_a.rgb, art_b.rgb, 1.0 - lerpfactor);

    // 3. Image Fetch (3 سحبات مع دمج الـ Fringing)
    float total_fring = 1.0 + fring;
    vec2 offset_x = vec2(resInvSize.x * total_fring, 0.0);
    
    vec3 Cur_Left  = texture2D(Texture, vTexCoord - offset_x).rgb;
    vec3 Cur_Local = texture2D(Texture, vTexCoord).rgb;
    vec3 Cur_Right = texture2D(Texture, vTexCoord + offset_x).rgb;

    // 4. Apply Artifacts & Hue Shift
    float total_art_power = Tuning_Artifacts + (afacts * 0.5);
    vec3 TunedNTSC = NTSCArtifact * total_art_power;
    
    // تطبيق الـ Artifacts أولاً
    Cur_Local = clamp(Cur_Local + (((Cur_Left - Cur_Local) + (Cur_Right - Cur_Local)) * TunedNTSC), 0.0, 1.0);

    // --- إضافة الـ Hue Shift داخل فضاء YIQ ---
    vec3 yiq = Cur_Local * RGB_to_YIQ;
    float hue_angle = ntsc_hue * 6.28318;
    float cosH = cos(hue_angle);
    float sinH = sin(hue_angle);
    
    vec2 rotated_IQ;
    rotated_IQ.x = yiq.y * cosH - yiq.z * sinH;
    rotated_IQ.y = yiq.y * sinH + yiq.z * cosH;
    
    Cur_Local = vec3(yiq.x, rotated_IQ) * YIQ_to_RGB;

    // 5. Advanced Sharpness
    float curBrt = Brightness(Cur_Local);
    float NBrtL  = Brightness(Cur_Left);
    float NBrtR  = Brightness(Cur_Right);
    
    float total_sharp = Tuning_Sharp + (ntsc_sharp * 0.2);
    float sharp_diff = (curBrt * 2.0 - NBrtL - NBrtR);
    
    Cur_Local = clamp(Cur_Local + (sharp_diff * total_sharp * mix(vec3(1.0), NTSCArtifact, total_art_power)), 0.0, 1.0);

    gl_FragColor = vec4(Cur_Local, 1.0);
} 
#endif