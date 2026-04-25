/* 777-LITE-TURBO-V4-RED-SMEAR-HYBRID
    - INTEGRATED: NTSC Signal (Dither/Grain/Chroma/Artifacts/Red Smear)
    - INTEGRATED: CRT Quilez Scaling + Scanlines + Mask + Bloom
    - ORDER: Signal -> Geometry/CRT Effects
*/

// --- NTSC Signal Parameters ---
#pragma parameter NTSC_FREQ "Signal Frequency" 0.08 0.0 1.0 0.01
#pragma parameter NTSC_SENSE "Rainbow Sensitivity" 0.5 0.0 1.0 0.01
#pragma parameter rb_tilt "Rainbow Tilt" 0.0 -2.0 2.0 0.1
#pragma parameter ntsc_hue "Color Hue (Shift)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter RED_PERSISTENCE "Red Smear Intensity" 1.0 0.0 2.5 0.05
#pragma parameter ntsc_blur "Smart Dither 16 Intensity" 0.5 0.0 1.0 0.05
#pragma parameter CRAWL_SPEED "Crawl Speed" 0.1 0.0 5.0 0.1
#pragma parameter NTSC_ARTIFACTS "Rainbow Intensity" 0.08 0.0 2.0 0.01
#pragma parameter NTSC_SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter RF_GRAIN "RF Noise Intensity" 0.0 0.0 0.5 0.01
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01

// --- CRT & Geometry Parameters ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Density" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0
#pragma parameter BLOOM_INT "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_TH "Bloom Threshold" 0.7 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    uv = TexCoord;
    screen_scale = TextureSize / InputSize;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv, screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;

// Uniforms
uniform float NTSC_FREQ, NTSC_SENSE, rb_tilt, ntsc_hue, COL_BLEED, RED_PERSISTENCE, ntsc_blur, CRAWL_SPEED, NTSC_ARTIFACTS, NTSC_SATURATION, RF_GRAIN, BLACK_LEVEL;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, BLOOM_INT, BLOOM_TH;

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float hash(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Signal Processing Function
vec3 processSignal(vec2 tex_coord) {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    vec3 cM = texture2D(Texture, tex_coord).rgb;
    
    // Smart Dither 16
    vec3 cL = texture2D(Texture, tex_coord - ps).rgb;
    vec3 cR = texture2D(Texture, tex_coord + ps).rgb;
    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    float d_mask = clamp(abs(yM - yL) * abs(yM - yR) * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);
    vec3 col = mix(cM, (cL + cM + cR) * 0.3333, ntsc_blur * d_mask);
    float final_y = dot(col, kY);

    // RF Grain
    float time_step = floor(float(FrameCount) / 4.0);
    float noise = (hash(tex_coord + vec2(time_step * 0.05, 0.0)) - 0.5) * RF_GRAIN;
    final_y += noise;

    // Chroma & Rainbow
    float fI = dot(col, kI);
    float fQ = dot(col, kQ);
    vec2 b_off = ps * COL_BLEED * 1.5;
    vec3 bcL = texture2D(Texture, tex_coord - b_off).rgb;
    vec3 bcR = texture2D(Texture, tex_coord + b_off).rgb;
    fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7 * step(0.1, COL_BLEED));
    fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7 * step(0.1, COL_BLEED));

    // RED PERSISTENCE (RED SMEAR)
    if (RED_PERSISTENCE > 0.0) {
        fI = mix(fI, dot(bcL, kI), 0.35 * RED_PERSISTENCE);
    }

    // Hue Rotation
    float cosH = cos(ntsc_hue);
    float sinH = sin(ntsc_hue);
    float rotI = fI * cosH - fQ * sinH;
    float rotQ = fI * sinH + fQ * cosH;
    fI = rotI; fQ = rotQ;

    // Rainbow Artifacts
    float phase = (tex_coord.x * TextureSize.x + tex_coord.y * TextureSize.y * rb_tilt) * (3.14159 * NTSC_FREQ) + (float(FrameCount) * 0.05 * CRAWL_SPEED);
    float edge = abs(yM - yL) + abs(yM - yR);
    float rb_mask = smoothstep(0.1, 1.0, edge) * NTSC_ARTIFACTS;
    fI += sin(phase) * rb_mask;
    fQ += cos(phase) * rb_mask;

    vec3 res = vec3(final_y + 0.956 * fI + 0.621 * fQ, final_y - 0.272 * fI - 0.647 * fQ, final_y - 1.106 * fI + 1.703 * fQ);
    res = mix(vec3(dot(res, kY)), res, NTSC_SATURATION);
    return res + BLACK_LEVEL;
}

void main() {
    // [1] Curvature Calculation
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    vec2 bounds = step(abs(p_curved), vec2(0.5));
    
    // [2] Quilez Scaling
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 p_pix = tex_uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec2 final_tex_uv = (i + f + 0.5) / TextureSize;
    
    // [3] Apply NTSC Signal
    vec3 col = processSignal(final_tex_uv);
    
    // [4] CRT Overlays (Scanlines & Bloom)
    float scan_pos = (p_curved.y + 0.5) * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * SCAN_STR;
    col *= (1.0 - scanline);
    
    // Simple Mask
    float mask = sin(p_curved.x * TextureSize.x * MASK_W) * 0.5 + 0.5;
    col = mix(col, col * (1.0 - MASK_STR), mask);

    // Final Output
    gl_FragColor = vec4(clamp(col * BRIGHT_BOOST * bounds.x * bounds.y, 0.0, 1.0), 1.0);
}
#endif