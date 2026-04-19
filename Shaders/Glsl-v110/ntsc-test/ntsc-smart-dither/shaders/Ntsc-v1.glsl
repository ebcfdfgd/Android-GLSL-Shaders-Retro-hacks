// --- NTSC MEGA LITE + CHROMA (Optimized for Mobile/G90T) ---
// Final Version: Analog Noise + Vertical Jailbars Integration

#version 110

#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.10 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 5.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.25 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed (0=OFF)" 0.05 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.1
#pragma parameter ntsc_blur "NTSC Dither Blur" 1.0 0.0 2.0 0.1
#pragma parameter analog_noise "Analog Signal Noise" 0.05 0.0 6.50 0.01
#pragma parameter JAIL_STR "MD Vertical Jailbars" 0.10 0.0 1.0 0.01
#pragma parameter JAIL_WIDTH "Jailbar Spacing" 2.0 0.5 10.0 0.1
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.0 0.0 1.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#else
#define ntsc_hue 0.0
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
uniform float ntsc_hue, COL_BLEED, red_persistence, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, ntsc_blur, analog_noise, JAIL_STR, JAIL_WIDTH, tv_mist;
#else
#define COL_BLEED 1.0
#define red_persistence 1.0
#define rb_power 0.15
#define rb_size 3.0
#define rb_detect 0.30
#define rb_speed 0.5
#define rb_tilt 0.5
#define ntsc_blur 1.0
#define analog_noise 0.05
#define JAIL_STR 0.1
#define JAIL_WIDTH 2.0
#define tv_mist 0.1
#endif

float rand(vec2 co, float seed) {
    return fract(sin(dot(co.xy + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

const vec3 luma_vec = vec3(0.2989, 0.5870, 0.1140);
const vec3 chroma_i_vec = vec3(0.5959, -0.2744, -0.3216);
const vec3 chroma_q_vec = vec3(0.2115, -0.5229, 0.3114);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    float time_seed = mod(float(FrameCount), 100.0);

    // --- 1. SMART FETCHES ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    float yM = dot(col_m, luma_vec);
    float yL = dot(col_l, luma_vec);
    float yR = dot(col_r, luma_vec);

    // --- 2. DITHER MASK ---
    float is_dither = abs(yM - yL) * abs(yM - yR); 
    float dither_mask = clamp(is_dither * 60.0, 0.0, 1.0);
    float edge_check = abs(yL - yR);
    dither_mask *= clamp(1.0 - edge_check * 2.0, 0.0, 1.0);

    // --- SMART NTSC BLUR ---
    vec3 col = col_m;
    if (ntsc_blur > 0.0) {
        vec3 avg = (col_l + col_m + col_r) * 0.33333;
        col = mix(col_m, avg, ntsc_blur * dither_mask);
    }
    
    vec3 yiq = col * RGBtoYIQ;

    // --- 3. CHROMA BLEED & RED PERSISTENCE ---
    vec2 mixed_chroma = yiq.gb;
    if (COL_BLEED > 0.0 || red_persistence > 0.0) {
        float bleed_offset = ps.x * COL_BLEED * 2.0;
        vec3 raw_cL = texture2D(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb;
        vec3 raw_cR = texture2D(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb;
        
        vec2 chrL = vec2(dot(raw_cL, chroma_i_vec), dot(raw_cL, chroma_q_vec));
        vec2 chrR = vec2(dot(raw_cR, chroma_i_vec), dot(raw_cR, chroma_q_vec));
        
        mixed_chroma = mix(yiq.gb, (chrL + chrR) * 0.5, 0.5);

        if (red_persistence > 0.0) {
            float i_smear = mix(yiq.g, chrL.x, 0.4 * red_persistence);
            mixed_chroma.x = mix(mixed_chroma.x, i_smear, 0.5);
        }
    }

    // --- 4. RAINBOW GENERATION ---
    float rainbowI = 0.0;
    float rainbowQ = 0.0;
    if (rb_speed > 0.0 && rb_power > 0.0) {
        float edge = abs(yM - yL) + abs(yM - yR);
        float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * dither_mask;
        float angle = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (float(FrameCount) * rb_speed); 
        rainbowI = sin(angle) * rb_power * rb_mask;
        rainbowQ = cos(angle) * rb_power * rb_mask;
    }

    // --- 5. ANALOG NOISE & JAILBARS & FINAL LUMA ---
    float final_y = (tv_mist > 0.0) ? mix(yiq.r, (yL + yiq.r + yR) * 0.33333, tv_mist) : yiq.r;
    
    // Analog Noise
    if (analog_noise > 0.0) {
        float signal_interference = rand(vTexCoord, time_seed);
        final_y += (signal_interference - 0.5) * analog_noise;
    }

    // MD Vertical Jailbars
    if (JAIL_STR > 0.0) {
        final_y += sin(vTexCoord.x * TextureSize.x * JAIL_WIDTH) * JAIL_STR * 0.05;
    }

    // --- 6. HUE SHIFT & ASSEMBLY ---
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    float hueI = fI * hue_trig.x - fQ * hue_trig.y;
    float hueQ = fI * hue_trig.y + fQ * hue_trig.x;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif