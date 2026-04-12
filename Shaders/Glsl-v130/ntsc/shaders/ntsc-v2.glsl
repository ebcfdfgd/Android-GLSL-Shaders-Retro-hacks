#version 130

#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

in vec2 vTexCoord;
out vec4 FragColor;

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

// --- البارامترات المنقحة ---
#pragma parameter PHASE_MODE "Phase Mode: 0:Manual, 1:2-Phase, 2:3-Phase" 0.0 0.0 2.0 1.0
#pragma parameter rb_power "Rainbow Strength" 0.1 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width/Scale" 4.5 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt/Rotation" 0.0 -2.0 2.0 0.05
#pragma parameter rb_detect "Rainbow Edge Detect" 0.31 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.1 0.0 1.0 0.01
#pragma parameter rb_phase "Rainbow Phase Shift" 0.0 0.0 6.28 0.1
#pragma parameter rb_sat "Rainbow Saturation" 1.0 0.0 2.0 0.05

#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 3.0 0.0 20.0 0.1
#pragma parameter black_bleed "Black Level Smear" 0.2 0.0 1.0 0.01
#pragma parameter fringe_str "Edge Color Fringing" 0.4 0.0 5.0 0.1
#pragma parameter tv_mist "Signal Blur (Mist)" 0.0 0.0 5.0 0.1

#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1
#pragma parameter NOISE_STR "Analog Signal Noise" 0.04 0.0 2.0 0.01
#pragma parameter JITTER "Signal Jitter (Shake)" 0.04 0.0 3.0 0.05

#pragma parameter MD_WARM "Analog Warmth" 0.05 -0.2 0.2 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.1 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Tint (Hue)" 0.0 -3.14 3.14 0.05

uniform float PHASE_MODE, rb_power, rb_size, rb_slant, rb_detect, rb_speed, rb_phase, rb_sat;
uniform float COL_BLEED, black_bleed, fringe_str;
uniform float de_dither, jail_str, jail_width;
uniform float MD_WARM, MD_SHARP, ntsc_hue, tv_mist;
uniform float NOISE_STR, JITTER;

const mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
const mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    vec2 uv = vTexCoord;

    // 1. JITTER & Mist
    uv.x += (rand(vec2(time, uv.y)) - 0.5) * JITTER * ps.x;
    uv.x += sin(time * 0.1) * tv_mist * 0.0005;

    // 2. Fetch الأساسي (بدون سحبات الـ Glow)
    vec3 main_c = texture(Texture, uv).rgb;
    
    // 3. De-Dither (سحبات لازمة لتنعيم مياه سونيك فقط)
    vec3 cL = texture(Texture, uv - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 cR = texture(Texture, uv + vec2(ps.x * de_dither, 0.0)).rgb;
    
    // خلط الـ De-Dither بنسبة بسيطة جداً للحفاظ على الحدة
    vec3 col = mix(main_c, (cL + cR) * 0.5, 0.3); 
    
    float jail = sin(uv.x * TextureSize.x * jail_width) * jail_str;

    // 4. Signal Analysis (YIQ)
    vec3 yiq = col * RGBtoYIQ;
    float lumaL = (cL * RGBtoYIQ).r;
    float lumaR = (cR * RGBtoYIQ).r;

    // 5. Rainbow Effect
    float p_slant = rb_slant; float p_speed = rb_speed;
    if (PHASE_MODE == 1.0) { p_slant = 0.0; p_speed = 0.5; }
    else if (PHASE_MODE == 2.0) { p_slant = 1.0; p_speed = 0.33; }

    float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
    float ang = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * p_slant) + (time * p_speed) + rb_phase;
    vec2 rb_vec = vec2(sin(ang), cos(ang)) * rb_power * rb_mask * rb_sat;
    
    // 6. Chroma Bleed (تسييح الألوان - كروما 00)
    float b_off = ps.x * COL_BLEED;
    vec2 chrL = (texture(Texture, uv - vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;
    vec2 chrR = (texture(Texture, uv + vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;
    vec2 chroma = (yiq.gb + chrL + chrR) * 0.333; 

    // 7. Luma Processing (ضبط الحدة)
    float y = yiq.r;
    y += (yiq.r - lumaL) * MD_SHARP; 
    y -= black_bleed * smoothstep(0.3, 0.0, y) * 0.2; 
    y += jail * 0.2; 
    y += (rand(uv + time * 0.01) - 0.5) * NOISE_STR;

    // 8. Final Assembly
    float fI = chroma.x + rb_vec.x + (yiq.r - lumaR) * fringe_str * 0.5;
    float fQ = chroma.y + rb_vec.y - (yiq.r - lumaL) * fringe_str * 0.3;
    
    float cA = cos(ntsc_hue); float sA = sin(ntsc_hue);
    vec3 final_yiq = vec3(y, fI * cA - fQ * sA, fI * sA + fQ * cA);
    vec3 final_rgb = final_yiq * YIQtoRGB;

    final_rgb.r += MD_WARM;

    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif