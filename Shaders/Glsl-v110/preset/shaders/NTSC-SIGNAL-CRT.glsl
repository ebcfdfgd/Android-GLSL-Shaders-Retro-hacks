/* 777-LITE-TURBO-V4-HYBRID-NTSC-SIGNAL-RED-SMEAR
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
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter NTSC_SHARP "Safe Sharpening" 0.5 0.0 2.0 0.1
#pragma parameter CRAWL_SPEED "Crawl Speed" 0.1 0.0 5.0 0.1
#pragma parameter NTSC_ARTIFACTS "Rainbow Intensity" 0.08 0.0 2.0 0.01
#pragma parameter NTSC_SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter RF_GRAIN "RF Noise Intensity" 0.0 0.0 0.5 0.01
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01

// --- CRT Parameters ---
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
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;
varying vec2 uv, screen_scale; 

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    screen_scale = TextureSize / InputSize; 
}

#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv, screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;

// Uniforms
uniform float NTSC_FREQ, NTSC_SENSE, rb_tilt, ntsc_hue, COL_BLEED, RED_PERSISTENCE, de_dither, NTSC_SHARP, CRAWL_SPEED, NTSC_ARTIFACTS, NTSC_SATURATION, RF_GRAIN, BLACK_LEVEL;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, BLOOM_INT, BLOOM_TH;

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    // 1. CRT Geometry Logic (Coordinate Warping)
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. NTSC Signal Processing
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    vec3 cM = texture2D(Texture, tex_uv).rgb;
    vec3 cL = texture2D(Texture, tex_uv - ps * max(de_dither, 1.0)).rgb;
    vec3 cR = texture2D(Texture, tex_uv + ps * max(de_dither, 1.0)).rgb;

    float yM = dot(cM, kY);
    float final_y = mix(yM, (dot(cL, kY) + dot(cR, kY)) * 0.5, 0.5 * de_dither);
    final_y += (hash(tex_uv + vec2(floor(float(FrameCount) / 4.0) * 0.05, 0.0)) - 0.5) * RF_GRAIN;
    final_y += clamp((final_y - (dot(cL, kY) + dot(cR, kY)) * 0.5) * NTSC_SHARP, -0.1, 0.1); 

    float fI = dot(cM, kI);
    float fQ = dot(cM, kQ);
    vec2 b_off = ps * COL_BLEED * 1.5; 
    vec3 bcL = texture2D(Texture, tex_uv - b_off).rgb;
    vec3 bcR = texture2D(Texture, tex_uv + b_off).rgb;
    
    fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7 * step(0.1, COL_BLEED));
    fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7 * step(0.1, COL_BLEED));

    // --- Red Smear Implementation ---
    if (RED_PERSISTENCE > 0.0) {
        fI = mix(fI, dot(bcL, kI), 0.35 * RED_PERSISTENCE);
    }

    float cosH = cos(ntsc_hue); float sinH = sin(ntsc_hue);
    float rotI = fI * cosH - fQ * sinH;
    float rotQ = fI * sinH + fQ * cosH;
    fI = rotI; fQ = rotQ;

    float phase = (tex_uv.x * TextureSize.x + tex_uv.y * TextureSize.y * rb_tilt) * (3.14159 * NTSC_FREQ) + (float(FrameCount) * 0.05 * CRAWL_SPEED);
    float rb_mask = smoothstep(0.1, 1.0, abs(yM - dot(cL, kY)) + abs(yM - dot(cR, kY))) * NTSC_ARTIFACTS;
    fI += sin(phase) * rb_mask; fQ += cos(phase) * rb_mask;

    vec3 res = vec3(final_y + 0.956 * fI + 0.621 * fQ, final_y - 0.272 * fI - 0.647 * fQ, final_y - 1.106 * fI + 1.703 * fQ);
    res = mix(vec3(dot(res, kY)), res, NTSC_SATURATION);
    res += BLACK_LEVEL;

    // 3. CRT Effects (Scanlines, Mask, Bloom)
    float scanline = sin((p_curved.y + 0.5) * InputSize.y * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);
    float pos = mod(gl_FragCoord.x, floor(MASK_W)) / floor(MASK_W);
    res = mix(res, res * clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6), MASK_STR);
    res += res * max(0.0, dot(res, kY) - BLOOM_TH) * BLOOM_INT;
    res *= BRIGHT_BOOST * (1.0 - r2 * VIG_STR);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0) * check, 1.0);
}
#endif