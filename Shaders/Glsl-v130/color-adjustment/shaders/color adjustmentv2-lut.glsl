#version 130

/*
    LIGHT-ULTIMATE (Turbo-E Gamma Edition - v130)
    - Updated: Modern GLSL 1.30 Syntax (in/out/texture).
    - Optimized: E-Square Glow Targeting (Power 5.0 for Zero-Bleed).
    - Logic: Linear Space LUT Integration.
    - Performance: Fast Power Math for CRT Phosphor look.
*/

// --- 1. LUT Parameters ---
#pragma parameter CLU_LUT_Size "LUT Size (16, 32, 64)" 32.0 1.0 64.0 1.0
#pragma parameter CLU_LUT_SEL "LUT Switch: -1:Off, 0:On" -1.0 -1.0 0.0 1.0
#pragma parameter CLU_LUT_OPACITY "LUT Opacity" 1.0 0.0 1.0 0.05

// --- 2. CRT Display Parameters ---
#pragma parameter CLU_GAMMA "CRT Gamma Curve" 2.4 1.0 3.5 0.05
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
uniform sampler2D SamplerLUT1;

#ifdef PARAMETER_UNIFORM
uniform float CLU_LUT_Size, CLU_LUT_SEL, CLU_LUT_OPACITY;
uniform float CLU_GAMMA, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

// وظيفة الـ LUT المحدثة لإصدار 130
vec3 apply_3d_lut(sampler2D sampler, vec3 color, float size) {
    float red = (color.r * (size - 1.0) + 0.4999) / (size * size);
    float green = (color.g * (size - 1.0) + 0.4999) / size;
    float blue = color.b * (size - 1.0);
    float b_low = floor(blue) / size;
    float b_high = ceil(blue) / size;
    
    // استخدام texture بدلاً من texture2D
    vec4 c1 = texture(sampler, vec2(b_low + red, green));
    vec4 c2 = texture(sampler, vec2(b_high + red, green));
    return mix(c1.rgb, c2.rgb, fract(blue));
}

void main() {
    vec4 texel = texture(Texture, TEX0);
    vec3 res = texel.rgb;

    // 1. FAST GAMMA LINEARIZATION
    res = pow(max(res, 0.0), vec3(CLU_GAMMA));

    // 2. LUT LOGIC (In Linear Space for Accuracy)
    if (CLU_LUT_SEL > -0.5 && CLU_LUT_OPACITY > 0.0) {
        vec3 l_res = apply_3d_lut(SamplerLUT1, res, CLU_LUT_Size);
        res = mix(res, l_res, CLU_LUT_OPACITY);
    }

    // 3. CONTRAST & SATURATION
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.299, 0.587, 0.114)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // 4. IMPROVED BLACK DEPTH
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // 5. THE FIX: Targeting White (E-Square)
    // Power 5.0 ensures only bright phosphors get the glow
    vec3 highlight_mask = pow(max(res, 0.0), vec3(5.0)); 
    res += highlight_mask * (CLU_GLOW + highlight_mask * CLU_HALATION);
    
    // Final Gain Boost
    res *= (CLU_BRIGHT * 1.05);

    // 6. OUTPUT CORRECTION
    // إعادة التحويل لمنطقة الـ Display باستخدام مقلوب الجاما لضمان توازن السطوع
    FragColor = vec4(pow(max(res, 0.0), vec3(1.0 / CLU_GAMMA)), texel.a);
}
#endif