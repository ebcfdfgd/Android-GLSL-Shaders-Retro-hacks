// --- NTSC MEGA LITE + CHROMA (Zero-Value Kill Switch) ---
// Optimized for Android - Features disable entirely at 0.0

#version 110

#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.0 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed (0=OFF)" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Signal Grain (RF Noise)" 0.01 0.0 0.20 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain;
#endif

float noise(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);

    // --- 1. THE FETCHES (Smart Dithering) ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    vec3 col_l = col_m;
    vec3 col_r = col_m;

    // إذا كان الديزر 0، لا تقم بجلب عينات إضافية (توفير أداء)
    if (de_dither > 0.0) {
        col_l = texture2D(Texture, vTexCoord - vec2(ps.x * de_dither, 0.0)).rgb;
        col_r = texture2D(Texture, vTexCoord + vec2(ps.x * de_dither, 0.0)).rgb;
    }

    vec3 col = (de_dither > 0.0) ? mix(col_m, (col_l + col_r) * 0.5, 0.4) : col_m;
    vec3 yiq = col * RGBtoYIQ;

    // --- 2. CHROMA BLEED (Kill Switch) ---
    vec2 mixed_chroma = yiq.gb;
    if (COL_BLEED > 0.0) {
        float bleed_offset = ps.x * COL_BLEED * 2.0;
        vec2 chrL = (texture2D(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb * RGBtoYIQ).gb;
        vec2 chrR = (texture2D(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb * RGBtoYIQ).gb;
        mixed_chroma = mix(yiq.gb, (chrL + chrR) * 0.5, 0.5);
    }

    // --- 3. RAINBOW GENERATION (Kill Switch) ---
    float rainbowI = 0.0;
    float rainbowQ = 0.0;
    if (rb_speed > 0.0 && rb_power > 0.0) {
        float lumaL = (col_l * RGBtoYIQ).r;
        float lumaR = (col_r * RGBtoYIQ).r;
        float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
        float rb_mask = smoothstep(rb_detect, rb_detect + 0.2, edge);
        
        float x_pos = vTexCoord.x * TextureSize.x;
        float y_pos = vTexCoord.y * TextureSize.y;
        float angle = (x_pos / rb_size) + (y_pos * rb_tilt) + (time * rb_speed) + ntsc_hue; 
        
        rainbowI = sin(angle) * rb_power * rb_mask;
        rainbowQ = cos(angle) * rb_power * rb_mask;
    }

    // --- 4. GRAIN & FINAL LUMA ---
    float final_y = yiq.r;
    if (ntsc_grain > 0.0) {
        final_y += (noise(vTexCoord + mod(time, 60.0)) - 0.5) * ntsc_grain;
    }

    // --- 5. HUE SHIFT & FINAL ASSEMBLY ---
    float cosA = cos(ntsc_hue);
    float sinA = sin(ntsc_hue);
    
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    float hueI = fI * cosA - fQ * sinA;
    float hueQ = fI * sinA + fQ * cosA;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif