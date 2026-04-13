#version 130

/* NTSC MEGA LITE + CHROMA (Rainbow Tilt + Motion + De-Dither + Grain)
   - Version 130 Build (Modern Syntax)
   - Optimized: Hue Trigs calculated in Vertex for Maximum Speed.
   - Performance: Exactly 5 Texture Samples.
*/

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
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 vTexCoord;
out vec2 hue_trig; 
uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#endif

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    // حساب الـ Hue مرة واحدة فقط لكل رأس (Vertex) لتوفير جهد المعالجة
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
precision highp float;

in vec2 vTexCoord;
in vec2 hue_trig; 
out vec4 FragColor;

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
#endif

float noise(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    float bleed_offset = ps.x * COL_BLEED * 2.0;

    // --- 1. THE 5 FETCHES ---
    vec3 col_m = texture(Texture, vTexCoord).rgb;
    vec3 col_l = texture(Texture, vTexCoord - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_r = texture(Texture, vTexCoord + vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_chrL = texture(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb;
    vec3 col_chrR = texture(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb;

    // --- 2. DE-DITHER & LUMA ANALYSIS ---
    vec3 col = mix(col_m, (col_l + col_r) * 0.5, 0.4);
    vec3 yiq = col * RGBtoYIQ;
    float lumaL = (col_l * RGBtoYIQ).r;
    float lumaR = (col_r * RGBtoYIQ).r;

    // --- 3. CHROMA BLEED ---
    vec2 chrL = (col_chrL * RGBtoYIQ).gb;
    vec2 chrR = (col_chrR * RGBtoYIQ).gb;
    vec2 mixed_chroma = mix(yiq.gb, (chrL + chrR) * 0.5, 0.5);

    // --- 4. RAINBOW GENERATION (TILT & MOTION) ---
    float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.2, edge);
    
    float x_pos = vTexCoord.x * TextureSize.x;
    float y_pos = vTexCoord.y * TextureSize.y;
    
    float angle = (x_pos / rb_size) + (y_pos * rb_tilt) + (time * rb_speed) + ntsc_hue; 
    
    float rainbowI = sin(angle) * rb_power * rb_mask;
    float rainbowQ = cos(angle) * rb_power * rb_mask;

    // --- 5. GRAIN & FINAL LUMA ---
    float final_y = mix(yiq.r, (lumaL + yiq.r + lumaR) * 0.333, tv_mist);
    final_y += (noise(vTexCoord + mod(time, 60.0)) - 0.5) * ntsc_grain;

    // --- 6. HUE SHIFT & FINAL ASSEMBLY ---
    // استخدام القيم الجاهزة الممررة من الـ Vertex لتقليل تكلفة الحساب في كل بكسل
    float cosA = hue_trig.x;
    float sinA = hue_trig.y;
    
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    float hueI = fI * cosA - fQ * sinA;
    float hueQ = fI * sinA + fQ * cosA;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif