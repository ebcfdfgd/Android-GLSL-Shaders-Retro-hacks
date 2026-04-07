/* ZABOULA-THEMAISTER ULTIMATE (NTSC MEGA LITE + FULL CONTROL)
   - Integrated: Resolution, Sharpness, Fringing, Artifacts.
   - Optimized for Android - Hue Trigs in Vertex.
*/

#version 110

#pragma parameter ntsc_res "Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.0 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Signal Grain (RF Noise)" 0.01 0.0 0.20 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.1 0.0 1.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 

uniform mat4 MVPMatrix;
#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#endif

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hue_trig; 

#ifdef PARAMETER_UNIFORM
uniform float ntsc_res, ntsc_sharp, fring, afacts, ntsc_hue, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
#endif

float noise(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    // دمج الـ Resolution في حساب الـ Pixel Size
    float res_mod = 1.0 - (ntsc_res * 0.5);
    vec2 ps = vec2(res_mod / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    float bleed_offset = ps.x * COL_BLEED * 2.0;

    // --- 1. THE FETCHES ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_chrL = texture2D(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb;
    vec3 col_chrR = texture2D(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb;

    // --- 2. DE-DITHER & LUMA ANALYSIS ---
    vec3 col = mix(col_m, (col_l + col_r) * 0.5, 0.4);
    vec3 yiq = col * RGBtoYIQ;
    float lumaL = dot(col_l, vec3(0.2989, 0.5870, 0.1140));
    float lumaR = dot(col_r, vec3(0.2989, 0.5870, 0.1140));

    // --- 3. SHARPNESS LOGIC ---
    // دمج الـ Sharpness لتقوية الحواف
    float sharp = (yiq.r - (lumaL + lumaR) * 0.5) * ntsc_sharp;
    yiq.r += sharp;

    // --- 4. CHROMA BLEED & ARTIFACTS ---
    vec2 mixed_chroma = mix(yiq.gb, (dot(col_chrL, vec3(0.5,0.5,0.5)) + dot(col_chrR, vec3(0.5,0.5,0.5))) * 0.5 * vec2(0.5959, 0.2115), 0.5);
    
    // --- 5. RAINBOW GENERATION (FRINGING & ARTIFACTS) ---
    float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.2, edge);
    
    float x_pos = vTexCoord.x * TextureSize.x;
    float y_pos = vTexCoord.y * TextureSize.y;
    float angle = (x_pos / rb_size) + (y_pos * rb_tilt) + (time * rb_speed) + ntsc_hue; 
    
    // ربط الـ Artifacts و الـ Fringing بقوة الرينبو
    float rb_final_power = rb_power + (afacts * 0.5) + (fring * 0.5);
    float rainbowI = sin(angle) * rb_final_power * rb_mask;
    float rainbowQ = cos(angle) * rb_final_power * rb_mask;

    // --- 6. GRAIN & FINAL LUMA ---
    float final_y = mix(yiq.r, (lumaL + yiq.r + lumaR) * 0.333, tv_mist);
    final_y += (noise(vTexCoord + mod(time, 60.0)) - 0.5) * ntsc_grain;

    // --- 7. FINAL ASSEMBLY ---
    float cosA = hue_trig.x;
    float sinA = hue_trig.y;
    
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    float hueI = fI * cosA - fQ * sinA;
    float hueQ = fI * sinA + fQ * cosA;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif