#version 100
precision mediump float;

// --- الباراميترز ---
#pragma parameter rb_opacity "Rainbow Intensity" 0.1 0.0 2.0 0.01
#pragma parameter rb_threshold "Detection Sensitivity" 0.35 0.0 0.8 0.01 
#pragma parameter rb_zoom "Rainbow Scale" 10.0 0.1 50.0 0.1
#pragma parameter rb_speed "Animation Speed" 0.0 0.0 4.0 0.01
#pragma parameter rb_tilt "Rainbow Tilt (Rotate)" 0.0 -3.14 3.14 0.1
#pragma parameter rb_sat "Rainbow Saturation" 1.0 -0.5 5.0 0.05
#pragma parameter de_dither "MD De-Dither (Sonic Water)" 0.7 0.0 2.0 0.1
#pragma parameter NOISE_STR "Analog Signal Noise" 0.00 0.0 0.5 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.1 0.0 1.5 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.2 0.0 20.0 0.05
#pragma parameter horiz_sharp "Horizontal Sharpen" 0.3 0.0 2.0 0.05
#pragma parameter CRAWL_SPEED "Rainbow Crawl Speed" 0.0 0.0 2.0 0.001
#pragma parameter JITTER "Signal Jitter (Shake)" 0.01 0.0 0.5 0.01
#pragma parameter ntsc_hue "NTSC Hue (Tint)" 0.0 -0.5 0.5 0.02

#ifdef VERTEX
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0;
varying vec2 vRainbowUV;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;
uniform vec2 InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    vRainbowUV = TexCoord.xy * (TextureSize / 256.0) * (InputSize / TextureSize);
}
#endif

#ifdef FRAGMENT
varying vec2 TEX0;
varying vec2 vRainbowUV;
uniform sampler2D Texture;
uniform sampler2D PNG2; 
uniform int FrameCount;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float rb_opacity, rb_threshold, rb_zoom, rb_speed, rb_tilt, rb_sat, de_dither, NOISE_STR, tv_mist, COL_BLEED, horiz_sharp;
uniform float CRAWL_SPEED, JITTER, ntsc_hue;
#endif

#define RGB_TO_YIQ(c) vec3(dot(c, vec3(0.2989, 0.5870, 0.1140)), dot(c, vec3(0.5959, -0.2744, -0.3216)), dot(c, vec3(0.2115, -0.5229, 0.3114)))
float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.98, 78.23))) * 437.5); }

void main() {
    float time = float(FrameCount);
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    
    // 1. JITTER (إيقاف تام عند الصفر)
    vec2 uv = TEX0;
    if(JITTER > 0.0) {
        uv.x += (rand(vec2(time, TEX0.y)) - 0.5) * JITTER * ps.x;
    }

    // 2. SIGNAL PROCESSING (De-Dither Kill Switch)
    vec3 main_col = texture2D(Texture, uv).rgb;
    vec3 col = main_col;
    vec3 c_left = main_col;
    vec3 c_right = main_col;

    if(de_dither > 0.0) {
        c_left  = texture2D(Texture, uv - ps * de_dither).rgb;
        c_right = texture2D(Texture, uv + ps * de_dither).rgb;
        col = (main_col * 0.5) + (c_left * 0.25) + (c_right * 0.25);
    }
    vec3 res = RGB_TO_YIQ(col);

    // 3. CHROMA & HUE (Kill Switch)
    vec2 mixed_chroma = res.gb;
    if(COL_BLEED > 0.0) {
        float bleed = ps.x * COL_BLEED;
        vec2 chrL = RGB_TO_YIQ(texture2D(Texture, uv - vec2(bleed, 0.0)).rgb).gb;
        vec2 chrR = RGB_TO_YIQ(texture2D(Texture, uv + vec2(bleed, 0.0)).rgb).gb;
        mixed_chroma = (res.gb + chrL + chrR) * 0.3333;
    }

    if(ntsc_hue != 0.0) {
        float h_s = sin(ntsc_hue); float h_c = cos(ntsc_hue);
        mixed_chroma = vec2(mixed_chroma.x * h_c - mixed_chroma.y * h_s, 
                            mixed_chroma.x * h_s + mixed_chroma.y * h_c);
    }

    // 4. SHARPENING & MIST
    float yC = res.r;
    float yL = (de_dither > 0.0) ? RGB_TO_YIQ(c_left).r : yC;
    float yR = (de_dither > 0.0) ? RGB_TO_YIQ(c_right).r : yC;
    
    float final_y = yC;
    if(horiz_sharp > 0.0) {
        final_y = yC + (yC * 2.0 - yL - yR) * horiz_sharp;
    }

    if(tv_mist > 0.0) {
        final_y = mix(final_y, (yL + yC + yR) * 0.3333, tv_mist);
    }
    
    if(NOISE_STR > 0.0) {
        final_y += (rand(uv + time * 0.01) - 0.5) * NOISE_STR;
    }

    // 5. FINAL ASSEMBLY & RAINBOW KILL SWITCH
    vec3 final_rgb;
    final_rgb.r = final_y + 0.9563 * mixed_chroma.x + 0.6210 * mixed_chroma.y;
    final_rgb.g = final_y - 0.2721 * mixed_chroma.x - 0.6474 * mixed_chroma.y;
    final_rgb.b = final_y - 1.1070 * mixed_chroma.x + 1.7046 * mixed_chroma.y;

    vec3 result = final_rgb;

    // إذا كانت الشفافية صفراً، لا يتم حساب الرينبو أو سحب الـ PNG نهائياً
    if(rb_opacity > 0.0) {
        vec2 pUV = vRainbowUV / rb_zoom;
        float offset = (time * rb_speed * 0.02) + (time * CRAWL_SPEED * 0.1);
        pUV.x += offset;
        pUV.y += mod(time, 2.0) * 0.5;

        if(rb_tilt != 0.0) {
            float s = sin(rb_tilt); float c = cos(rb_tilt);
            pUV = vec2(pUV.x * c - pUV.y * s, pUV.x * s + pUV.y * c);
        }

        vec3 pngCol = texture2D(PNG2, fract(pUV)).rgb;
        if(rb_sat != 1.0) {
            pngCol = mix(vec3(dot(pngCol, vec3(0.299, 0.587, 0.114))), pngCol, rb_sat);
        }

        float mask = clamp((abs(yC - yL) + abs(yC - yR)) - rb_threshold, 0.0, 1.0) * 5.0;
        result = mix(final_rgb, pngCol, mask * rb_opacity);
    }

    gl_FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
#endif