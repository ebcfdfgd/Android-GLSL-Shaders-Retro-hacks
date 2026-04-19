#version 100
precision mediump float;

// --- NTSC MEGA LITE (TURBO OPTIMIZED) ---

#pragma parameter ntsc_blur "NTSC Dither Blur" 0.7 0.0 2.0 0.1
#pragma parameter rb_opacity "Rainbow Intensity" 0.1 0.0 2.0 0.01
#pragma parameter rb_zoom "Rainbow Scale" 10.0 0.1 50.0 0.1
#pragma parameter rb_speed "Animation Speed" 0.0 0.0 4.0 0.01
#pragma parameter rb_tilt "Rainbow Tilt (Rotate)" 0.0 -3.14 3.14 0.1
#pragma parameter rb_sat "Rainbow Saturation" 1.0 -0.5 5.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
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
varying vec2 vHueTrig; // حساب الجا والجتا هنا يوفر ملايين العمليات
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    vRainbowUV = TexCoord.xy * (TextureSize / 256.0) * (InputSize / TextureSize);
    
    // حساب دوران الألوان مرة واحدة لكل إطار بدلاً من كل بكسل
    float angle = ntsc_hue * 3.14159;
    vHueTrig = vec2(sin(angle), cos(angle));
}
#endif

#ifdef FRAGMENT
varying vec2 TEX0;
varying vec2 vRainbowUV;
varying vec2 vHueTrig;
uniform sampler2D Texture;
uniform sampler2D PNG2; 
uniform int FrameCount;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_blur, rb_opacity, rb_zoom, rb_speed, rb_tilt, rb_sat, red_persistence, NOISE_STR, tv_mist, COL_BLEED, horiz_sharp;
uniform float CRAWL_SPEED, JITTER;
#endif

// ثوابت التحويل (أسرع من تعريفها كـ Function)
const vec3 y_v = vec3(0.2989, 0.5870, 0.1140);
const vec3 i_v = vec3(0.5959, -0.2744, -0.3216);
const vec3 q_v = vec3(0.2115, -0.5229, 0.3114);

float rand(vec2 co){ return fract(sin(dot(co ,vec2(12.98, 78.23))) * 437.5); }

void main() {
    float time = float(FrameCount);
    vec2 ps = 1.0 / TextureSize;
    vec2 uv = TEX0;
    
    if(JITTER > 0.0) uv.x += (rand(vec2(time, uv.y)) - 0.5) * JITTER * ps.x;

    // 1. Fetching (سحب البكسلات مرة واحدة)
    vec3 col_m = texture2D(Texture, uv).rgb;
    vec3 col_l = texture2D(Texture, uv - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, uv + vec2(ps.x, 0.0)).rgb;

    // 2. Optimized YIQ Conversion (Dot product أسرع بكتير)
    float yM = dot(col_m, y_v);
    float yL = dot(col_l, y_v);
    float yR = dot(col_r, y_v);

    // 3. Smart Dither Mask (Logic 113)
    float is_dither = abs(yM - yL) * abs(yM - yR); 
    float dither_mask = clamp(is_dither * 50.0, 0.0, 1.0);
    dither_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);

    // 4. Chroma & Persistence Logic
    float cur_i = dot(col_m, i_v);
    float cur_q = dot(col_m, q_v);
    
    if(COL_BLEED > 0.0) {
        float bleed = ps.x * COL_BLEED;
        vec3 cL = texture2D(Texture, uv - vec2(bleed, 0.0)).rgb;
        vec3 cR = texture2D(Texture, uv + vec2(bleed, 0.0)).rgb;
        
        float i_avg = (cur_i + dot(cL, i_v) + dot(cR, i_v)) * 0.3333;
        float q_avg = (cur_q + dot(cL, q_v) + dot(cR, q_v)) * 0.3333;
        
        cur_i = i_avg; cur_q = q_avg;

        if(red_persistence > 0.0) {
            cur_i = mix(cur_i, dot(cL, i_v), 0.24 * red_persistence);
        }
    }

    // Hue Rotation (استخدام قيم الجا والجتا المحسوبة مسبقاً)
    if(vHueTrig.x != 0.0 || vHueTrig.y != 1.0) {
        float fI = cur_i * vHueTrig.y - cur_q * vHueTrig.x;
        float fQ = cur_i * vHueTrig.x + cur_q * vHueTrig.y;
        cur_i = fI; cur_q = fQ;
    }

    // 5. Luma Processing
    float final_y = (ntsc_blur > 0.0) ? mix(yM, (yL + yM + yR) * 0.3333, ntsc_blur * dither_mask) : yM;
    if(horiz_sharp > 0.0) final_y += (final_y * 2.0 - yL - yR) * horiz_sharp;
    if(tv_mist > 0.0) final_y = mix(final_y, (yL + yM + yR) * 0.3333, tv_mist);
    if(NOISE_STR > 0.0) final_y += (rand(uv + time * 0.01) - 0.5) * NOISE_STR;

    // 6. Final RGB Assembly (Manual Matrix)
    vec3 result = vec3(
        final_y + 0.956 * cur_i + 0.621 * cur_q,
        final_y - 0.272 * cur_i - 0.647 * cur_q,
        final_y - 1.107 * cur_i + 1.705 * cur_q
    );

    // 7. Rainbow Engine (PNG2)
    if(rb_opacity > 0.0) {
        vec2 pUV = vRainbowUV / rb_zoom;
        pUV.x += (time * rb_speed * 0.02) + (time * CRAWL_SPEED * 0.1);
        pUV.y += mod(time, 2.0) * 0.5;

        if(rb_tilt != 0.0) {
            float s = sin(rb_tilt); float c = cos(rb_tilt);
            pUV = vec2(pUV.x * c - pUV.y * s, pUV.x * s + pUV.y * c);
        }

        vec3 pngCol = texture2D(PNG2, fract(pUV)).rgb;
        if(rb_sat != 1.0) pngCol = mix(vec3(dot(pngCol, y_v)), pngCol, rb_sat);
        
        result = mix(result, pngCol, dither_mask * rb_opacity);
    }

    gl_FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
#endif