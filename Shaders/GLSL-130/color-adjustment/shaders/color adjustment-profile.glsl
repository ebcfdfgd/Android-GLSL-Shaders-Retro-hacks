#version 130

/* CRT-LIGHT-ULTIMATE (Pro-E Gamma Edition - v130)
    - Updated: GLSL 1.30 Syntax (in/out/texture).
    - Feature: Fast Gamma Engine with Dynamic Curve.
    - Profiles: Europe (EBU), America (SMPTE-C), Japan (NTSC-J).
    - Logic: High-Luma Focused Glow in Linear Space.
*/

// --- 1. Color Profile & Gamma ---
#pragma parameter CLU_PROFILE "Color Profile (EU, US, JP)" 0.0 0.0 3.0 1.0
#pragma parameter CLU_GAMMA "CRT Gamma Curve" 2.4 1.0 3.5 0.05

// --- 2. Color Adjustments ---
#pragma parameter CLU_CONTRAST "CRT Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05

#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    TEX0 = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
precision highp float;

in vec2 TEX0;
out vec4 FragColor;

uniform sampler2D Texture;

#ifdef PARAMETER_UNIFORM
uniform float CLU_PROFILE, CLU_GAMMA, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

// Advanced Color Matrices
const mat3 SMPTE_RGB = mat3(0.95, 0.05, 0.0,  0.02, 0.98, 0.0,  0.0, 0.05, 0.95); // Warmer US
const mat3 NTSC_J_RGB = mat3(0.9, 0.1, 0.0,  0.05, 0.9, 0.05,  0.0, 0.1, 1.1); // Cooler Japan

void main() {
    vec4 texel = texture(Texture, TEX0);
    vec3 res = texel.rgb;

    // 1. FAST GAMMA LINEARIZATION
    res = pow(max(res, 0.0), vec3(CLU_GAMMA));

    // 2. APPLY REGIONAL COLOR PROFILE
    if (CLU_PROFILE > 1.5 && CLU_PROFILE < 2.5) {
        // America (SMPTE-C)
        res = clamp(res * SMPTE_RGB, 0.0, 1.0);
    } 
    else if (CLU_PROFILE > 2.5) {
        // Japan (NTSC-J)
        res = clamp(res * NTSC_J_RGB, 0.0, 1.0);
    }

    // 3. CONTRAST & SATURATION (Linear Space)
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.299, 0.587, 0.114)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // 4. BLACK DEPTH
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // 5. HIGH-LUMA GLOW & HALATION
    vec3 glow_mask = pow(max(res, 0.0), vec3(4.0));
    res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);
    
    res *= CLU_BRIGHT;

    // 6. OUTPUT GAMMA CORRECTION
    // تم توحيد المخرج النهائي ليعتمد على نفس قيمة الجاما للحصول على دقة ألوان فائقة
    FragColor = vec4(pow(max(res, 0.0), vec3(1.0 / CLU_GAMMA)), texel.a);
}
#endif