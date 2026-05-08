/* --- 777-NTSC-HYBRID-ULTIMATE-V3.5 ---
    - ADDED: Red Persistence (Phosphor Decay/Ghosting).
    - ADDED: NTSC Hue, Brightness, and Black Level.
    - FEATURE: Smart Dither detection (Hybrid logic).
    - IMPROVED: Red ghosting effect for authentic CRT motion.
*/

#version 110

// --- [ RetroArch Parameters ] ---
#pragma parameter NTSC_BRIGHT "NTSC Brightness" 1.0 0.5 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.2 0.5 0.01
#pragma parameter RED_PERSIST "Red Persistence (Ghosting)" 0.0 0.0 0.5 0.05
#pragma parameter ntsc_hue "NTSC Hue Adjustment" 0.0 -0.5 0.5 0.01
#pragma parameter CC_FREQ "NTSC Color Clock" 3.5979 0.0 10.0 0.1
#pragma parameter NTSC_TILT "NTSC Rainbow Tilt" 0.0 0.0 2.0 0.05
#pragma parameter JITTER_STR "NTSC Rotation Speed" 0.0 0.0 2.0 0.05
#pragma parameter ARTF_STR "NTSC Artifacting" 0.45 0.0 2.0 0.05
#pragma parameter RAINBOW_STR "NTSC Rainbow" 0.3 0.0 1.0 0.05
#pragma parameter CHROMA_BLEED "NTSC Chroma Bleed" 1.6 0.0 5.0 0.1
#pragma parameter SHARPNESS "NTSC Sharpness" 0.2 -1.0 1.0 0.05
#pragma parameter SATURATION "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter sig_noise "Signal RF Grain (Namash)" 0.04 0.0 0.5 0.01

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
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHT, BLACK_LEVEL, RED_PERSIST, ntsc_hue, CC_FREQ, NTSC_TILT, JITTER_STR, ARTF_STR, RAINBOW_STR, CHROMA_BLEED, SHARPNESS, SATURATION, ntsc_blur, sig_noise;
#endif

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 pos = vTexCoord;
    float time = float(FrameCount);
    vec3 col_center = texture2D(Texture, pos).rgb;

    // --- 1. SMART BYPASS ---
    if (ARTF_STR <= 0.0 && RAINBOW_STR <= 0.0 && CHROMA_BLEED <= 0.0 && SHARPNESS <= 0.0 && ntsc_blur <= 0.0 && sig_noise <= 0.0 && BLACK_LEVEL == 0.0 && NTSC_BRIGHT == 1.0 && RED_PERSIST == 0.0) {
        float luma_raw = dot(col_center, kY);
        vec3 final_rgb = mix(vec3(luma_raw), col_center, SATURATION);
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
    float rotation = mod(time * JITTER_STR, 6.28318);
    float phase = (pos.x * TextureSize.x * CC_FREQ + pos.y * TextureSize.y * NTSC_TILT) + rotation; 
    
    vec3 sharp_col = col + (col - (col_l + col_r) * 0.5) * SHARPNESS;
    float y = dot(sharp_col, kY);
    
    if (sig_noise > 0.0) y += (hash(pos + time * 0.01) - 0.5) * sig_noise;

    float i = dot(sharp_col, kI);
    float q = dot(sharp_col, kQ);

    float luma_diff = dot(col_center - col_l, kY);
    i += luma_diff * cos(phase) * ARTF_STR;
    q += luma_diff * sin(phase) * ARTF_STR;
    
    float rb = cos(phase) * luma_diff * RAINBOW_STR * d_mask;
    i += rb; q -= rb; 

    // --- 4. CHROMA & HUE ---
    if (CHROMA_BLEED > 0.1) {
        vec2 b_off = texel * CHROMA_BLEED;
        vec3 bcL = texture2D(Texture, pos - b_off).rgb;
        vec3 bcR = texture2D(Texture, pos + b_off).rgb;
        i = mix(i, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7);
        q = mix(q, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7);
    }

    if (ntsc_hue != 0.0) {
        float h_sin = sin(ntsc_hue); float h_cos = cos(ntsc_hue);
        float i_n = i * h_cos - q * h_sin;
        float q_n = i * h_sin + q * h_cos;
        i = i_n; q = q_n;
    }

    // --- 5. FINAL ASSEMBLY & RED PERSISTENCE ---
    vec3 rgb;
    rgb.r = y + 0.956 * i + 0.621 * q;
    rgb.g = y - 0.272 * i - 0.647 * q;
    rgb.b = y - 1.106 * i + 1.703 * q;

    // Apply Red Persistence Effect (Simulating Phosphor Decay)
    if (RED_PERSIST > 0.0) {
        float p_mask = fract(time * 0.5); // Fast temporal jitter
        rgb.r = mix(rgb.r, col_center.r, RED_PERSIST * p_mask);
    }
    
    rgb = (rgb * NTSC_BRIGHT) + BLACK_LEVEL;
    rgb = mix(vec3(dot(rgb, kY)), rgb, SATURATION);

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif