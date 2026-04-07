#version 110

/*
    NTSC Shader - Ultra Optimized (Backported to 110)
    - 7 Samples Architecture: extremely efficient for mobile GPUs.
    - Features: NTSC Artifacts, Signal Crawl, and Dynamic Sharpness.
    - Logic: Zero extra fetches for sharpening.
*/

// --- PARAMETERS ---
#pragma parameter Tuning_Sharp "Composite Sharp" 0.0 -30.0 1.0 0.05
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

#ifdef PARAMETER_UNIFORM
uniform float Tuning_Sharp, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
#endif

// دالة حساب السطوع المتوافقة مع 110
float Brightness(vec3 InVal) { 
    return dot(InVal, vec3(0.299, 0.587, 0.114)); 
}

void main()
{
    vec2 invSize = 1.0 / TextureSize;
    
    // 1. حساب إحداثيات الـ Artifacts (سحبتان من تكتشر الضوضاء)
    float time_offset = float(FrameCount) * Crawl_Speed * 0.01; 
    vec2 scanuv = (TEX0 * TextureSize) / NTSCArtifactScale;
    scanuv.x += time_offset;
    
    // تطبيق تدوير الإشارة (NTSC Tilt)
    float cosA = cos(NTSC_Tilt); 
    float sinA = sin(NTSC_Tilt);
    scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
    scanuv = fract(scanuv);

    vec4 art_a = texture2D(NTSCArtifactSampler2, scanuv);
    vec4 art_b = texture2D(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y));
    
    float lerpfactor = (animate_artifacts > 0.5) ? mod(float(FrameCount), 2.0) : NTSCLerp;
    vec3 NTSCArtifact = mix(art_a.rgb, art_b.rgb, 1.0 - lerpfactor);

    // 2. سحب عينات الصورة الأساسية (3 سحبات مركزية)
    vec2 offset_x = vec2(invSize.x, 0.0);
    vec3 Cur_Left  = texture2D(Texture, TEX0 - offset_x).rgb;
    vec3 Cur_Local = texture2D(Texture, TEX0).rgb;
    vec3 Cur_Right = texture2D(Texture, TEX0 + offset_x).rgb;

    // 3. تطبيق الـ Artifacts (تداخل ألوان الـ Composite)
    vec3 TunedNTSC = NTSCArtifact * Tuning_Artifacts;
    Cur_Local = clamp(Cur_Local + (((Cur_Left - Cur_Local) + (Cur_Right - Cur_Local)) * TunedNTSC), 0.0, 1.0);

    // 4. الـ Sharpness المحسن (بدون سحبات إضافية)
    float curBrt = Brightness(Cur_Local);
    float NBrtL  = Brightness(Cur_Left);
    float NBrtR  = Brightness(Cur_Right);
    
    // استخدام الفرق المركزي (Central Difference) لتعزيز الحواف
    float sharp_diff = (curBrt * 2.0 - NBrtL - NBrtR);
    Cur_Local = clamp(Cur_Local + (sharp_diff * Tuning_Sharp * mix(vec3(1.0), NTSCArtifact, Tuning_Artifacts)), 0.0, 1.0);

    gl_FragColor = vec4(Cur_Local, 1.0);
} 
#endif