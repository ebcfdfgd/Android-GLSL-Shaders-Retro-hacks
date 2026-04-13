#version 130

/*
    Grade-Ultimate: World Profile Edition (Fast Gamma Build - v130)
    - Updated: Modern GLSL 1.30 Syntax (in/out/texture).
    - Fixed: Vertex attribute matching for Mali GPUs.
    - Added: G_GAMMA Parameter for dynamic curve control.
*/

#if defined(VERTEX)
in vec4 VertexCoord;
in vec4 TexCoord;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
precision mediump float;

in vec2 vTexCoord;
out vec4 FragColor;

uniform sampler2D Texture;

// --- Parameters ---
#pragma parameter G_GAMMA     "Fast Gamma"             2.2  1.0  3.5  0.05
#pragma parameter g_profile   "CRT Profile: 0-4"       0.0  0.0  4.0  1.0
#pragma parameter g_r         "Red Weight"             1.0  0.0  2.0  0.02
#pragma parameter g_g         "Green Weight"           1.0  0.0  2.0  0.02
#pragma parameter g_b         "Blue Weight"            1.0  0.0  2.0  0.02
#pragma parameter g_glow      "Soft Glow Strength"     0.15 0.0  0.5  0.05
#pragma parameter g_lift      "OLED Black Depth"       0.03 0.0  0.2  0.01
#pragma parameter g_vibr      "Smart Vibrance"         0.35 0.0  1.5  0.05
#pragma parameter g_cntrst    "Sigmoidal Contrast"     0.1  0.0  1.0  0.05
#pragma parameter g_pivot     "Contrast Pivot"         0.5  0.0  1.0  0.05

#ifdef PARAMETER_UNIFORM
uniform float G_GAMMA, g_profile, g_r, g_g, g_b, g_glow, g_lift, g_vibr, g_cntrst, g_pivot;
#endif

void main() {
    // استخدام texture بدلاً من texture2D
    vec3 col = texture(Texture, vTexCoord).rgb;

    // 0. Linearize using Fast Gamma
    col = pow(max(col, 0.0), vec3(G_GAMMA));

    // 1. Profile System
    vec3 prof = vec3(1.0);
    if (g_profile > 0.5) {
        if (g_profile < 1.5)      prof = vec3(1.10, 0.95, 0.90); // NTSC
        else if (g_profile < 2.5) prof = vec3(0.95, 1.05, 0.95); // PAL
        else if (g_profile < 3.5) prof = vec3(1.00, 1.05, 1.10); // PVM
        else                      prof = vec3(0.92, 0.97, 1.15); // J-NTSC
    }
    
    // 2. RGB Gain
    col *= prof * vec3(g_r, g_g, g_b);

    // 3. OLED Black Depth
    col = max(col - g_lift, 0.0) / (1.0 - g_lift);

    // 4. Soft Glow
    if (g_glow > 0.0) {
        vec3 glow_effect = smoothstep(0.4, 1.0, col);
        col += glow_effect * g_glow;
    }

    // 5. Smart Vibrance
    float max_c = max(col.r, max(col.g, col.b));
    float min_c = min(col.r, min(col.g, col.b));
    float sat_mask = (max_c - min_c) / (max_c + 1.0e-5);
    col = mix(col, vec3(max_c), g_vibr * (1.0 - sat_mask));

    // 6. Sigmoidal Contrast
    col = (col - g_pivot) * (g_cntrst + 1.0) + g_pivot;

    // 7. Output Gamma Correction
    FragColor = vec4(pow(max(col, 0.0), vec3(1.0 / G_GAMMA)), 1.0);
}
#endif