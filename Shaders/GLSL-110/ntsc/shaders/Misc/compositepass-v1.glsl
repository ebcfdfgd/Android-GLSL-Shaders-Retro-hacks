#version 110

/*
    NTSC-ULTIMATE - Light Version (Backported to 110)
    - Optimized: Uses only 8 total samples.
    - Logic: High-speed Persistence & Smart Sharpness.
*/

// --- PARAMETERS ---
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
uniform float Tuning_Sharp, Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B;
uniform float Tuning_Bleed, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
#endif

float Brightness(vec3 InVal) { 
    return dot(InVal, vec3(0.299, 0.587, 0.114)); 
}

void main()
{
    vec2 invSize = 1.0 / TextureSize;
    
    // 1. حساب إحداثيات الـ Artifacts (سحبتان)
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

    // 2. سحب الصورة الحالية (3 سحبات فقط)
    vec2 dx = vec2(invSize.x, 0.0);
    vec3 Cur_L = texture2D(Texture, TEX0 - dx).rgb;
    vec3 Cur_M = texture2D(Texture, TEX0).rgb;
    vec3 Cur_R = texture2D(Texture, TEX0 + dx).rgb;

    // 3. تطبيق الـ Artifacts & Sharpness
    vec3 res = Cur_M + ((Cur_L - Cur_M) + (Cur_R - Cur_M)) * NTSCArtifact * Tuning_Artifacts;
    
    float bM = Brightness(res);
    float bL = Brightness(Cur_L);
    float bR = Brightness(Cur_R);
    
    // تعزيز الحدة باستخدام الفروقات المتاحة بالفعل
    float sharp = (bM * 2.0 - bL - bR) * Tuning_Sharp;
    res = clamp(res + (sharp * mix(vec3(1.0), NTSCArtifact, Tuning_Artifacts)), 0.0, 1.0);

    // 4. Persistence (3 سحبات من الإطارات السابقة)
    vec3 p1 = texture2D(PrevTexture, TEX0).rgb;
    vec3 p2 = texture2D(Prev2Texture, TEX0).rgb;
    vec3 p4 = texture2D(Prev4Texture, TEX0).rgb;
    vec3 Prev_Avg = (p1 + p2 + p4) * 0.333;

    // دمج بقاء الصورة مع نزيف الألوان الافتراضي
    vec3 persist_color = vec3(Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B);
    res = max(res, persist_color * Prev_Avg * (10.0 / (1.0 + Tuning_Bleed)));

    gl_FragColor = vec4(res, 1.0);
} 
#endif