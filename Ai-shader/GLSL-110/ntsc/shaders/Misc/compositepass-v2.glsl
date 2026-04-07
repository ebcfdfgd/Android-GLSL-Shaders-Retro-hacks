#version 110

/*
    NTSC-ULTIMATE (Rainbow Fix Edition - Backported to 110)
    - Fix: Separated Artifact calculation from Chroma Bleed.
    - Logic: Persistence (Motion Blur/Phosphor Glow) using multi-frame buffers.
    - Stability: Compatible with older GLSL profiles.
*/

// --- 1. [ COMPOSITE TUNING ] ---
#pragma parameter Tuning_Sharp "Composite Sharp" 0.0 -30.0 1.0 0.05
#pragma parameter Tuning_Bleed "Composite Bleed" 0.5 0.0 1.0 0.05
#pragma parameter Tuning_Artifacts "Composite Artifacts" 0.5 0.0 1.0 0.05

// --- 2. [ PHOSPHOR PERSISTENCE ] ---
#pragma parameter Tuning_Persistence_R "Red Persistence" 0.075 0.0 1.0 0.01
#pragma parameter Tuning_Persistence_G "Green Persistence" 0.05 0.0 1.0 0.01
#pragma parameter Tuning_Persistence_B "Blue Persistence" 0.05 0.0 1.0 0.01

// --- 3. [ NTSC SIGNAL ] ---
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
uniform float Tuning_Sharp, Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B;
uniform float Tuning_Bleed, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
#endif

// مصفوفات تحويل الألوان الثابتة (Column-Major for GLSL 110)
const mat3 RGB_to_YIQ = mat3(0.299, 0.5959, 0.2115, 0.587, -0.2746, -0.5227, 0.114, -0.3213, 0.3112);
const mat3 YIQ_to_RGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

float Brightness(vec3 InVal) { 
    return dot(InVal, vec3(0.299, 0.587, 0.114)); 
}

void main()
{
    vec2 invSize = 1.0 / TextureSize;
    vec2 dx = vec2(invSize.x, 0.0);
    
    // [1] سحب عينات الصورة الخام لحساب الـ Artifacts
    vec3 cur_raw = texture2D(Texture, TEX0).rgb;
    vec3 Cur_L   = texture2D(Texture, TEX0 - dx).rgb;
    vec3 Cur_R   = texture2D(Texture, TEX0 + dx).rgb;

    // [2] حساب الـ NTSC Artifacts (Rainbow) بشكل مستقل
    float time_offset = float(FrameCount) * Crawl_Speed * 0.01; 
    vec2 scanuv = (TEX0 * TextureSize / NTSCArtifactScale);
    scanuv.x += time_offset;
    
    float cosA = cos(NTSC_Tilt); 
    float sinA = sin(NTSC_Tilt);
    scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
    scanuv = fract(scanuv);

    vec4 art_a = texture2D(NTSCArtifactSampler2, scanuv);
    vec4 art_b = texture2D(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y));
    float lerpfactor = (animate_artifacts > 0.5) ? mod(float(FrameCount), 2.0) : NTSCLerp;
    vec3 NTSCArtifact = mix(art_a.rgb, art_b.rgb, 1.0 - lerpfactor);

    // تطبيق قوس قزح قبل تسييح الألوان (Pre-Chroma)
    vec3 res = cur_raw + ((Cur_L - cur_raw) + (Cur_R - cur_raw)) * NTSCArtifact * Tuning_Artifacts;

    // [3] تطبيق نزيف الألوان (Chroma Bleed)
    vec3 c_m = res * RGB_to_YIQ;
    vec2 spread_dist = dx * (2.0 + Tuning_Bleed * 3.0);
    vec3 c_l = texture2D(Texture, TEX0 - spread_dist).rgb * RGB_to_YIQ;
    vec3 c_r = texture2D(Texture, TEX0 + spread_dist).rgb * RGB_to_YIQ;
    
    // دمج قنوات الألوان (I & Q) لنشر اللون دون تدمير تفاصيل قوس قزح
    vec2 spread_chroma = mix(c_m.yz, (c_l.yz + c_r.yz) * 0.5, Tuning_Bleed);
    res = vec3(c_m.x, spread_chroma) * YIQ_to_RGB;

    // [4] الحدة والوضوح (Sharpness)
    float bM = Brightness(res);
    float bL = Brightness(Cur_L);
    float bR = Brightness(Cur_R);
    float sharp = (bM * 2.0 - bL - bR) * Tuning_Sharp;
    res = clamp(res + sharp, 0.0, 1.0);

    // [5] نظام الـ Persistence (توهج الفسفور والحركة الناعمة)
    // سحب العينات من الإطارات السابقة (Buffers)
    vec3 p1 = texture2D(PrevTexture, TEX0).rgb;
    vec3 p2 = texture2D(Prev2Texture, TEX0).rgb;
    vec3 p4 = texture2D(Prev4Texture, TEX0).rgb;
    vec3 Prev_Avg = (p1 + p2 + p4) * 0.333;

    // تطبيق الـ Ghosting الخفيف بناءً على إعدادات الألوان
    vec3 persist_color = vec3(Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B);
    res = max(res, persist_color * Prev_Avg * (5.0 / (1.0 + Tuning_Bleed * 0.2)));

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
} 
#endif