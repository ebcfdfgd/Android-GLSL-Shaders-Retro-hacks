#version 130

/*
    NTSC-ULTIMATE (Rainbow Fix Edition)
    - Fix: Separated Artifact calculation from Chroma Bleed to prevent Rainbow distortion.
    - Feature: Preserves all Tuning parameters and Persistence logic.
*/

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
    uniform sampler2D PrevTexture;
    uniform sampler2D Prev2Texture;
    uniform sampler2D Prev4Texture;
    COMPAT_VARYING vec4 TEX0;

    #ifdef PARAMETER_UNIFORM
    uniform float Tuning_Sharp, Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B;
    uniform float Tuning_Bleed, Tuning_Artifacts, NTSCLerp, NTSCArtifactScale, animate_artifacts, Crawl_Speed, NTSC_Tilt;
    #endif

    const mat3 RGB_to_YIQ = mat3(0.299, 0.587, 0.114, 0.5959, -0.2746, -0.3213, 0.2115, -0.5227, 0.3112);
    const mat3 YIQ_to_RGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.106, 1.703);

    float Brightness(vec3 InVal) { return dot(InVal, vec3(0.299, 0.587, 0.114)); }

    void main()
    {
        vec2 SourceSize = vec2(TextureSize);
        vec2 invSize = 1.0 / SourceSize;
        vec2 dx = vec2(invSize.x, 0.0);
        
        // [1] Fetch Raw Image for Artifact calculation
        vec3 cur_raw = COMPAT_TEXTURE(Texture, TEX0.xy).rgb;
        vec3 Cur_L = COMPAT_TEXTURE(Texture, TEX0.xy - dx).rgb;
        vec3 Cur_R = COMPAT_TEXTURE(Texture, TEX0.xy + dx).rgb;

        // [2] Calculate NTSC Artifacts (Rainbow) independently
        float time_offset = float(FrameCount) * Crawl_Speed * 0.01; 
        vec2 scanuv = (TEX0.xy * SourceSize / NTSCArtifactScale);
        scanuv.x += time_offset;
        float cosA = cos(NTSC_Tilt); float sinA = sin(NTSC_Tilt);
        scanuv = vec2(scanuv.x * cosA - scanuv.y * sinA, scanuv.x * sinA + scanuv.y * cosA);
        scanuv = fract(scanuv);

        vec4 art_a = COMPAT_TEXTURE(NTSCArtifactSampler2, scanuv);
        vec4 art_b = COMPAT_TEXTURE(NTSCArtifactSampler2, scanuv + vec2(0.0, invSize.y));
        float lerpfactor = (animate_artifacts > 0.5) ? mod(float(FrameCount), 2.0) : NTSCLerp;
        vec3 NTSCArtifact = mix(art_a.rgb, art_b.rgb, 1.0 - lerpfactor);

        // Apply Artifacts to raw image BEFORE chroma bleed
        vec3 res = cur_raw + ((Cur_L - cur_raw) + (Cur_R - cur_raw)) * NTSCArtifact * Tuning_Artifacts;

        // [3] Apply Chroma Bleed on the result
        vec3 c_m = res * RGB_to_YIQ;
        vec3 c_l = COMPAT_TEXTURE(Texture, TEX0.xy - dx * (2.0 + Tuning_Bleed * 3.0)).rgb * RGB_to_YIQ;
        vec3 c_r = COMPAT_TEXTURE(Texture, TEX0.xy + dx * (2.0 + Tuning_Bleed * 3.0)).rgb * RGB_to_YIQ;
        
        // Mix only I & Q channels to spread color without destroying Rainbow details
        vec2 spread_chroma = mix(c_m.yz, (c_l.yz + c_r.yz) * 0.5, Tuning_Bleed);
        res = vec3(c_m.x, spread_chroma) * YIQ_to_RGB;

        // [4] Sharpness & Fidelity
        float bM = Brightness(res);
        float bL = Brightness(Cur_L);
        float bR = Brightness(Cur_R);
        float sharp = (bM * 2.0 - bL - bR) * Tuning_Sharp;
        res = clamp(res + sharp, 0.0, 1.0);

        // [5] Persistence Logic
        vec3 p1 = COMPAT_TEXTURE(PrevTexture, TEX0.xy).rgb;
        vec3 p2 = COMPAT_TEXTURE(Prev2Texture, TEX0.xy).rgb;
        vec3 p4 = COMPAT_TEXTURE(Prev4Texture, TEX0.xy).rgb;
        vec3 Prev_Avg = (p1 + p2 + p4) * 0.333;

        vec3 persist_color = vec3(Tuning_Persistence_R, Tuning_Persistence_G, Tuning_Persistence_B);
        res = max(res, persist_color * Prev_Avg * (5.0 / (1.0 + Tuning_Bleed * 0.2)));

        FragColor = vec4(res, 1.0);
    } 
#endif