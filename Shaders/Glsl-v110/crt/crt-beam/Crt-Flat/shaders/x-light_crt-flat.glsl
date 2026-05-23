#version 110

/* 777-LITE-TURBO-V4-ULTRA-FIXED (Flat Edition - Dynamic Beam)
    - REMOVED: Static Lottes Scanlines.
    - INTEGRATED: Dynamic Pixel-Synced Scan_Beam (reacts to luma).
    - SPEED: Zero-cost math, Branchless logic.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01

// --- Dynamic Scan_Beam Parameters ---
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_BEAM "Beam Glow (Fast React)" 1.2 0.5 3.0 0.1

#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05


#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 screen_scale; 
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

varying vec2 uv;
varying vec2 screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
// تم استبدال بارميترات لووتس ببارميترات السكان بيم الديناميكي المحسّن
uniform float BRIGHT_BOOST,  SCAN_STR, SCAN_BEAM, MASK_STR;
#endif

void main() {
    // 1. حساب موضع البكسل المسطح العادي
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p); // تركناه لحساب الـ Vignette بالأسفل بنجاح
    
    // 2. استخدام الإحداثيات المسطحة مباشرة وسحب الصورة النظيفة
    vec2 tex_uv = uv;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. فحص الحدود باستخدام p المسطحة لحماية الشادر من الشاشة السوداء
    vec2 bounds = step(abs(p), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. DYNAMIC SCAN_BEAM INTEGRATION (المحرك الديناميكي المتفاعل مع السطوع)
    float lum = dot(res, vec3(0.299, 0.587, 0.114));
    float pos_y = tex_uv.y * TextureSize.y;
    float dist = abs(fract(pos_y - 0.5) - 0.5);
    
    float beam_calc = dist * (SCAN_BEAM + (lum * 1.5));
    float scan = exp2(-(beam_calc * beam_calc)); 
    
    float scan_weight = mix(1.0, scan, SCAN_STR);
    res *= mix(1.0, scan_weight, step(0.01, SCAN_STR));

    // 5. RGB Mask
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;

    // اضرب النتيجة في بكسل الصورة بناءً على القوة المختارة
    res *= mix(vec3(1.0), mcol, MASK_STR);

    // 6. Final Polish
    res *= BRIGHT_BOOST;
   

    gl_FragColor = vec4(res * check, 1.0);
}
#endif