#version 130

/*
    NTSC Shader - Ultra Optimized (7 Samples)
    - Integrated: Resolution, Sharpness, Fringing, Artifacts
    - Maintained: 7-Sample efficiency and NTSC Tilt.
*/

// --- البارامترات الجديدة ---
#pragma parameter ntsc_res "Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05

// --- البارامترات الأصلية ---
#pragma parameter Tuning_Sharp "Composite Sharp" 0.0 -30.0 1.0 0.05
#pragma parameter Tuning_Artifacts "Composite Artifacts" 0.5 0.0 1.0 0.05
#pragma parameter NTSCLerp "NTSC Artifacts" 1.0 0.0 1.0 1.0
#pragma parameter NTSCArtifactScale "NTSC Artifact Scale" 255.0 0.0 1000.0 5.0
#pragma parameter animate_artifacts "Animate NTSC Artifacts" 1.0 0.0 1.0 1.0
#pragma parameter Crawl_Speed "NTSC Crawl Speed" 0.10 -2.0 2.0 0.01
#pragma parameter NTSC_Tilt "NTSC Texture Tilt" 0.0 -3.14 3.14 0.1

#define tex2D(a, b) COMPAT_TEXTURE(a, b)
#define saturate(c) clamp(c, 0.0, 1.0)

#if defined(VERTEX)
    #if __VERSION__ >= 130
        #define COMPAT_VARYING out
        #define COMPAT_ATTRIBUTE in
    #else
        #define COMPAT_VARYING varying 
        #define COMPAT_ATTRIBUTE attribute 
    #endif
    COMPAT_ATTRIBUTE vec4 VertexCoord;
    COMPAT_ATTRIBUTE vec4 TexCoord;
    COMPAT_VARYING vec4 TEX0;
    uniform mat4 MVPMatrix;
    void main() { gl_Position = MVPMatrix * VertexCoord; TEX0.xy = TexCoord.xy; }
#elif defined(FRAGMENT)
    precision highp float;
    #if __VERSION__ >= 130
        #define COMPAT_VARYING in
        #define COMPAT_TEXTURE texture
        out vec4 FragColor;
    #else
        #define COMPAT_VARYING varying
        #define FragColor gl_FragColor
        #define COMPAT_TEXTURE texture2D
    #endif

    uniform int FrameCount;
    uniform vec2 TextureSize;
    uniform sampler2D Texture;
    uniform sampler2D NTSCArtifactSampler2; 
    COMPAT_VARYING vec4 TEX0;

    #define Source Texture
    #define vTexCoord TEX0.xy
    #define SourceSize vec4(TextureSize, 1.0 / TextureSize)

    #ifdef PARAMETER_UNIFORM
    uniform float ntsc_res, ntsc_sharp, fring, afacts;
    uniform float Tuning_Sharp, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
    #endif

    float Brightness(vec4 InVal) { return dot(InVal, vec4(0.299, 0.587, 0.114, 0.0)); }

    void main()
    {
        // 1. Resolution & Pixel Geometry
        float res_step = 1.0 - (ntsc_res * 0.5);
        vec2 invSize = vec2(SourceSize.z * res_step, SourceSize.w);
        float time_offset = float(FrameCount) * Crawl_Speed * 0.01; 

        // 2. Artifacts Mapping (2 Samples)
        vec2 scanuv = (vTexCoord * SourceSize.xy) / NTSCArtifactScale;
        scanuv.x += time_offset;
        float cosA = cos(NTSC_Tilt); float sinA = sin(NTSC_Tilt);
        scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
        scanuv = fract(scanuv);

        vec4 art_a = tex2D(NTSCArtifactSampler2, scanuv);
        vec4 art_b = tex2D(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y));
        float lerpfactor = (animate_artifacts > 0.5) ? mod(float(FrameCount), 2.0) : NTSCLerp;
        vec4 NTSCArtifact = mix(art_a, art_b, 1.0 - lerpfactor);

        // 3. Image Fetch (3 Samples + Fringing Integration)
        float total_fring = 1.0 + fring;
        vec2 offset_x = vec2(invSize.x * total_fring, 0.0);
        
        vec4 Cur_Left  = tex2D(Source, vTexCoord - offset_x);
        vec4 Cur_Local = tex2D(Source, vTexCoord);
        vec4 Cur_Right = tex2D(Source, vTexCoord + offset_x);

        // 4. Apply Artifacts (دمج afacts الجديد)
        float total_art_power = Tuning_Artifacts + (afacts * 0.5);
        vec4 TunedNTSC = NTSCArtifact * total_art_power;
        Cur_Local = saturate(Cur_Local + (((Cur_Left - Cur_Local) + (Cur_Right - Cur_Local)) * TunedNTSC));

        // 5. Advanced Sharpness (Zero extra samples)
        float curBrt = Brightness(Cur_Local);
        float NBrtL  = Brightness(Cur_Left);
        float NBrtR  = Brightness(Cur_Right);
        
        float total_sharp = Tuning_Sharp + (ntsc_sharp * 0.2);
        float sharp_diff = (curBrt * 2.0 - NBrtL - NBrtR);
        Cur_Local = saturate(Cur_Local + (sharp_diff * total_sharp * mix(vec4(1.0), NTSCArtifact, total_art_power)));

        FragColor = vec4(Cur_Local.rgb, 1.0);
    } 
#endif