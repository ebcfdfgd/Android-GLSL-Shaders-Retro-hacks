/* 777-LITE-TURBO-V4-ULTRA-CLEAN-MASK-BLOOM
    - COMPATIBILITY: Universal Mask Prep + Dark/Light Controls.
    - FEATURES: Dynamic R/G/B/Y/C/M/K channel mapping.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05
#pragma parameter maskDark "Mask Dark Level" 0.5 0.0 2.0 0.05
#pragma parameter maskLight "Mask Light Level" 1.5 0.0 2.0 0.05

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, BLOOM_STR, SCAN_STR, hardScan, MASK_STR, maskDark, maskLight;
#endif

void main() {
    // 1. Coordinates & Curve
    vec2 p_coord = (uv * screen_scale) - 0.5;
    float r2 = dot(p_coord, p_coord);
    vec2 p_curved = p_coord * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Exact Game UVs
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. Bloom (Luminance Based)
    float lum = dot(res, vec3(0.299, 0.587, 0.114));
    res += (res * lum) * BLOOM_STR;

    // 4. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 5. SCANLINES (Lottes Method)
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 6. --- [ MASK PREP AREA - DUAL CONTROL ] ---
    vec2 p = gl_FragCoord.xy;
    vec3 mcol = vec3(1.0);
    float inv = maskDark; // للتوافق مع الأكواد القديمة التي تستخدم inv

    // تعريف الألوان بناءً على Dark و Light
    vec3 R = vec3(maskLight, maskDark, maskDark);
    vec3 G = vec3(maskDark, maskLight, maskDark);
    vec3 B = vec3(maskDark, maskDark, maskLight);
    vec3 M = vec3(maskLight, maskDark, maskLight);
    vec3 Y = vec3(maskLight, maskLight, maskDark);
    vec3 C = vec3(maskDark, maskLight, maskLight);
    vec3 K = vec3(maskDark);

    // --- [ PASTE YOUR MASK LOGIC BELOW ] ---
    { 
        // مثال: ماسك رقم 17 (يمكنك تبديله بأي سطر آخر)
         int r = int(mod(p.y, 2.0));
    int c = int(mod(p.x, 6.0));
    // السطر الأول: R G B K K K | السطر الثاني: K K K R G B
    mcol = (r == 0) ? (c == 0 ? R : (c == 1 ? G : (c == 2 ? B : K))) 
                    : (c == 3 ? R : (c == 4 ? G : (c == 5 ? B : K))); } 
    // --- [ PASTE YOUR MASK LOGIC ABOVE ] ---

    // دمج قوة الماسك النهائية
    res = mix(res, res * mcol, MASK_STR); 

    // 7. Final Polish
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);

    gl_FragColor = vec4(res * check, 1.0);
}
#endif