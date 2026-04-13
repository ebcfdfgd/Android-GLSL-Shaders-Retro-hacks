#version 110

#pragma parameter ntsc_rainbow "NTSC Rainbow Strength" 0.6 0.0 2.0 0.01
#pragma parameter ntsc_freq "NTSC Rainbow Frequency" 1.0 0.0 2.0 0.01
#pragma parameter ntsc_tilt "NTSC Rainbow Tilt" 0.0 -2.0 2.0 0.05
#pragma parameter ntsc_crawl "NTSC Dot Crawl Speed" 1.0 0.0 5.0 0.05
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter ntsc_fringing "NTSC Color Fringing" 0.3 0.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC Hue Adjustment" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_bleed "NTSC Chroma Bleed (General)" 1.5 0.0 2.0 0.05
#pragma parameter red_persistence "Red persistence (Right only)" 1.3 0.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 vPixCoord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    vPixCoord = TexCoord * TextureSize; 
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
varying vec2 vPixCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_rainbow, ntsc_freq, ntsc_tilt, ntsc_crawl, ntsc_blur, ntsc_fringing, ntsc_hue, ntsc_bleed, red_persistence;
#else
#define ntsc_rainbow 0.6
#define ntsc_freq 1.0
#define ntsc_tilt 0.5
#define ntsc_crawl 1.0
#define ntsc_blur 0.5
#define ntsc_fringing 0.3
#define ntsc_hue 0.0
#define ntsc_bleed 1.0
#define red_persistence 1.0
#endif

mat3 rgb2yiq = mat3(0.2989, 0.5959, 0.2115, 0.5870, -0.2744, -0.5229, 0.1140, -0.3216, 0.3114);
mat3 yiq2rgb = mat3(1.0, 1.0, 1.0, 0.956, -0.2720, -1.106, 0.6210, -0.6474, 1.7046);

void main() {
    float dx = 1.0 / TextureSize.x;
    float time = mod(float(FrameCount), 1024.0); // تقييد الرقم لضمان الدقة العالية
    
    vec3 cC  = texture2D(Texture, vTexCoord).rgb;
    vec3 cL  = texture2D(Texture, vTexCoord - vec2(dx, 0.0)).rgb;
    vec3 cR  = texture2D(Texture, vTexCoord + vec2(dx, 0.0)).rgb;

    vec3 yiqC  = cC  * rgb2yiq;
    vec3 yiqL  = cL  * rgb2yiq;
    vec3 yiqR  = cR  * rgb2yiq;

    // --- [ CHROMA BLEED ] ---
    float bleed_offset = dx * ntsc_bleed * 2.0;
    vec2 chrL = (texture2D(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb * rgb2yiq).gb;
    vec2 chrR = (texture2D(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb * rgb2yiq).gb;
    
    float mixed_I = mix(yiqC.y, (chrL.x + chrR.x) * 0.5, 0.5);
    float mixed_Q = mix(yiqC.z, (chrL.y + chrR.y) * 0.5, 0.5);
    
    if (red_persistence > 0.0) {
        float i_smear = mix(yiqC.y, chrL.x, 0.5 * red_persistence);
        mixed_I = mix(mixed_I, i_smear, 0.5);
    }
    
    vec3 final_col = vec3(yiqC.x, mixed_I, mixed_Q) * yiq2rgb;
    
    // --- [ DITHER MASK ] ---
    float yL = yiqL.x; float yC = yiqC.x; float yR = yiqR.x;
    float is_dither = abs(yC - yL) * abs(yC - yR); 
    float dither_mask = clamp(is_dither * 50.0, 0.0, 1.0);
    float edge_check = abs(yL - yR);
    dither_mask *= clamp(1.0 - edge_check * 5.0, 0.0, 1.0);

    // Fringing
    if (ntsc_fringing > 0.0) {
        final_col += (yL - yR) * ntsc_fringing * 0.2;
    }

    // Rainbow & Blur (Fixed Logic)
    if (ntsc_rainbow > 0.0 && dither_mask > 0.1) {
        float jitter = mod(time, 2.0) * 3.14159;
        // استخدام "time" المحددة بـ mod بدلاً من FrameCount المباشر
        float phase = (vPixCoord.x * 3.14159 * ntsc_freq) + (vPixCoord.y * ntsc_tilt) + (time * ntsc_crawl) + jitter;
        vec3 rainbow = vec3(sin(phase), sin(phase + 2.09), sin(phase + 4.18));
        final_col += rainbow * 0.2 * ntsc_rainbow * dither_mask;
    }

    if (ntsc_blur > 0.0 && dither_mask > 0.1) {
        vec3 avg = (cL + cC + cR) / 3.0;
        final_col = mix(final_col, avg, ntsc_blur * dither_mask);
    }

    // Hue Adjustment
    if (abs(ntsc_hue) > 0.001) {
        float s = sin(ntsc_hue); float c = cos(ntsc_hue);
        vec3 yiq = final_col * rgb2yiq;
        float i = yiq.y * c - yiq.z * s;
        float q = yiq.y * s + yiq.z * c;
        final_col = vec3(yiq.x, i, q) * yiq2rgb;
    }

    gl_FragColor = vec4(clamp(final_col, 0.0, 1.0), 1.0);
}
#endif