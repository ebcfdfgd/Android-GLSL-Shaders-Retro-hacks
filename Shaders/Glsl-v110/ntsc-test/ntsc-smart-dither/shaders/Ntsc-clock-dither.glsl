#version 110

/* NTSC-HYBRID ULTIMATE (Enhanced with Analog Artifacts)
   - Added: Analog Noise & MD Vertical Jailbars.
   - Fixed: Chroma Bleed and Red Persistence integration.
   - Optimization: Thermal-optimized Bypass including new artifacts.
*/

// --- [ RetroArch Parameters ] ---
#pragma parameter NTSC_BRIGHT "NTSC Brightness" 1.0 1.0 2.0 0.05
#pragma parameter CC_FREQ "NTSC Color Clock" 3.5979 0.0 10.0 0.1
#pragma parameter NTSC_TILT "NTSC Rainbow Tilt" 0.0 0.0 2.0 0.05
#pragma parameter JITTER_STR "NTSC Rotation Speed" 0.0 0.0 2.0 0.05
#pragma parameter ARTF_STR "NTSC Artifacting" 0.45 0.0 2.0 0.05
#pragma parameter RAINBOW_STR "NTSC Rainbow" 0.3 0.0 1.0 0.05
#pragma parameter CHROMA_BLEED "NTSC Chroma Bleed" 1.6 0.0 5.0 0.1
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter SHARPNESS "NTSC Sharpness" 0.2 -1.0 1.0 0.05
#pragma parameter SATURATION "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter noise_str "Analog Noise Intensity" 0.04 0.0 0.5 0.01
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "Jailbar Spacing" 1.5 0.5 10.0 0.1

#if defined(VERTEX)
uniform mat4 MVPMatrix;
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHT, CC_FREQ, NTSC_TILT, JITTER_STR, ARTF_STR, RAINBOW_STR, CHROMA_BLEED, red_persistence, SHARPNESS, SATURATION, ntsc_blur;
uniform float noise_str, jail_str, jail_width;
#endif

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 pos = vTexCoord;
    vec3 col_center = texture2D(Texture, pos).rgb;

    // --- 1. SMART BYPASS (Thermal Logic) ---
    if (ARTF_STR <= 0.0 && RAINBOW_STR <= 0.0 && CHROMA_BLEED <= 0.0 && red_persistence <= 0.0 && SHARPNESS <= 0.0 && ntsc_blur <= 0.0 && noise_str <= 0.0 && jail_str <= 0.0) {
        float luma_raw = dot(col_center * NTSC_BRIGHT, kY);
        vec3 final_rgb = mix(vec3(luma_raw), col_center * NTSC_BRIGHT, SATURATION);
        gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
        return; 
    }

    vec2 texel = vec2(1.0 / TextureSize.x, 0.0);
    vec3 col_l = texture2D(Texture, pos - texel).rgb;
    vec3 col_r = texture2D(Texture, pos + texel).rgb;

    // --- 2. DITHER DETECTION ---
    float yM = dot(col_center, kY);
    float yL = dot(col_l, kY);
    float yR = dot(col_r, kY);

    float is_dither = abs(yM - yL) * abs(yM - yR);
    float d_mask = clamp(is_dither * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);

    vec3 col = col_center;
    if (ntsc_blur > 0.0) {
        vec3 avg = (col_l + col_center + col_r) * 0.3333;
        col = mix(col_center, avg, ntsc_blur * d_mask);
    }

    // --- 3. PHASE & ARTIFACTS ---
    float rotation = mod(float(FrameCount) * JITTER_STR, 6.28318);
    float phase = (vTexCoord.x * TextureSize.x * CC_FREQ + vTexCoord.y * TextureSize.y * NTSC_TILT) + rotation; 
    
    float sub_i = cos(phase);
    float sub_q = sin(phase);

    // Luma & Sharpness
    vec3 sharp_col = col + (col - (col_l + col_r) * 0.5) * SHARPNESS;
    float y = dot(sharp_col, kY);
    
    // INSERTION: Analog Artifacts (Applied to Luma)
    if (jail_str > 0.0) y += sin(pos.x * TextureSize.x * jail_width) * jail_str * 0.02;
    if (noise_str > 0.0) y += (rand(pos + mod(float(FrameCount), 100.0) * 0.01) - 0.5) * noise_str;

    float i = dot(sharp_col, kI);
    float q = dot(sharp_col, kQ);

    // Artifacting (Fringing & Rainbow tied to d_mask)
    float luma_diff = dot(col_center - col_l, kY);
    i += luma_diff * sub_i * ARTF_STR;
    q += luma_diff * sub_q * ARTF_STR;
    
    float rb = cos(phase) * luma_diff * RAINBOW_STR * d_mask;
    i += rb;
    q -= rb; 

    // --- 4. CHROMA BLEED & RED PERSISTENCE ---
    if (CHROMA_BLEED > 0.1) {
        vec2 b_off = texel * CHROMA_BLEED;
        vec3 bcL = texture2D(Texture, pos - b_off).rgb;
        vec3 bcR = texture2D(Texture, pos + b_off).rgb;
        
        float i_bleed = (dot(bcL, kI) + dot(bcR, kI)) * 0.5;
        float q_bleed = (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5;
        
        i = mix(i, i_bleed, 0.7);
        q = mix(q, q_bleed, 0.7);

        if (red_persistence > 0.0) {
            float smearI = dot(bcL, kI);
            i = mix(i, smearI, 0.45 * red_persistence);
        }
    }

    // --- 5. FINAL ASSEMBLY ---
    vec3 rgb;
    rgb.r = y + 0.956 * i + 0.621 * q;
    rgb.g = y - 0.272 * i - 0.647 * q;
    rgb.b = y - 1.106 * i + 1.703 * q;
    
    rgb *= NTSC_BRIGHT;
    float luma_final = dot(rgb, kY);
    rgb = mix(vec3(luma_final), rgb, SATURATION);

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif