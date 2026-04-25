/* --- 777-NTSC-ADAPTIVE-ULTIMATE-V3 ---
   - FIXED: Precision issue (highp added) to stop noise banding.
   - FIXED: RF Grain logic (Floating & Powder-like "Namash").
   - OPTIMIZED: High-performance Smart Bypass maintained.
   - FEATURE: Natural boiling noise that doesn't repeat predictably.
   - UPDATED: Jailbars are now resolution independent.
*/

#version 110

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
#pragma parameter sig_noise "Signal RF Grain (Namash)" 0.05 0.0 0.5 0.01
#pragma parameter JAIL_STR "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter JAIL_WIDTH "MD Jailbar Spacing" 1.5 0.5 5.0 0.1

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
// السر في الـ highp عشان النمش يطلع بكسلات رفيعة مش خطوط
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHT, CC_FREQ, NTSC_TILT, JITTER_STR, ARTF_STR, RAINBOW_STR, CHROMA_BLEED, red_persistence, SHARPNESS, SATURATION;
uniform float sig_noise, JAIL_STR, JAIL_WIDTH;
#endif

// الهاش السحري للنمش الناعم
float hash(vec2 co) { 
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); 
}

void main() {
    vec2 pos = vTexCoord;
    float time = float(FrameCount);
    
    // [1] سحب العينة المركزية
    vec3 col_center = texture2D(Texture, pos).rgb;

    // --- شرط الإيقاف الذكي (Smart Bypass) لزيادة الأداء ---
    if (ARTF_STR <= 0.0 && RAINBOW_STR <= 0.0 && CHROMA_BLEED <= 0.0 && red_persistence <= 0.0 && SHARPNESS <= 0.0 && sig_noise <= 0.0 && JAIL_STR <= 0.0) {
        float luma_raw = dot(col_center * NTSC_BRIGHT, vec3(0.299, 0.587, 0.114));
        vec3 final_rgb = mix(vec3(luma_raw), col_center * NTSC_BRIGHT, SATURATION);
        gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
        return; 
    }

    vec2 pix = pos * TextureSize;
    vec2 texel = vec2(1.0 / TextureSize.x, 0.0);

    // --- 2. المرحلة (Phase) والتردد ---
    float rotation = mod(time * JITTER_STR, 6.28318);
    float phase = (pix.x * CC_FREQ + pix.y * NTSC_TILT) + rotation; 
    
    float sub_i = cos(phase);
    float sub_q = sin(phase);

    // 3. عينات الجوار (L/R) للحدة والنزيف
    vec3 col_left  = texture2D(Texture, pos - texel).rgb;
    vec3 col_right = texture2D(Texture, pos + texel).rgb;
    
    // 4. Sharpness & Luma Logic
    vec3 sharp_col = col_center + (col_center - (col_left + col_right) * 0.5) * SHARPNESS;
    float y = dot(sharp_col, vec3(0.2989, 0.5870, 0.1140));
    
    // --- إضافة النمش والجيلبارز (Resolution Independent) ---
    if (JAIL_STR > 0.0) 
        y += sin(pos.x * JAIL_WIDTH * 500.0) * JAIL_STR * 0.02;
        
    if (sig_noise > 0.0) 
        y += (hash(pos + time * 0.01) - 0.5) * sig_noise;

    // تحويل الألوان للـ YIQ المبدئي
    float i = dot(sharp_col, vec3(0.5959, -0.2744, -0.3216));
    float q = dot(sharp_col, vec3(0.2115, -0.5229, 0.3114));

    // 5. Artifacting (Fringing & Rainbow)
    float luma_diff = dot(col_center - col_left, vec3(0.299, 0.587, 0.114));
    
    i += luma_diff * sub_i * ARTF_STR;
    q += luma_diff * sub_q * ARTF_STR;
    
    float rb_val = cos(phase) * luma_diff * RAINBOW_STR;
    i += rb_val;
    q -= rb_val; 

    // 6. Chroma Bleeding & Red Persistence
    vec2 bleed_off = texel * CHROMA_BLEED;
    vec3 bleed_l = texture2D(Texture, pos - bleed_off).rgb;
    vec3 bleed_r = texture2D(Texture, pos + bleed_off).rgb;
    
    float i_l = dot(bleed_l, vec3(0.5959, -0.2744, -0.3216));
    float i_r = dot(bleed_r, vec3(0.5959, -0.2744, -0.3216));
    
    float i_bleed = (i_l + i_r) * 0.5;
    float q_bleed = (dot(bleed_l, vec3(0.2115, -0.5229, 0.3114)) + dot(bleed_r, vec3(0.2115, -0.5229, 0.3114))) * 0.5;
    
    i = mix(i, i_bleed, 0.75);
    q = mix(q, q_bleed, 0.75);

    // سيلان اللون الأحمر (Persistence)
    if (red_persistence > 0.0) {
        i = mix(i, mix(i, i_l, 0.4 * red_persistence), 0.6);
    }

    // 7. تحويل YIQ إلى RGB النهائي
    vec3 rgb;
    rgb.r = y + 0.956 * i + 0.621 * q;
    rgb.g = y - 0.272 * i - 0.647 * q;
    rgb.b = y - 1.106 * i + 1.703 * q;
    
    // 8. المعالجة النهائية (إضاءة وتشبع)
    rgb *= NTSC_BRIGHT;
    float luma_final = dot(rgb, vec3(0.299, 0.587, 0.114));
    rgb = mix(vec3(luma_final), rgb, SATURATION);

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif