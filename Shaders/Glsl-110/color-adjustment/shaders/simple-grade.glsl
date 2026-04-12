#version 110

/* Grade-Ultimate: World Profile Edition (Backported to 110)
    - Cleaned: Non-breaking spaces and hidden characters.
    - Fixed: Vertex attribute matching for Mali GPUs.
    - Feature: Regional CRT Color Grading Profiles.
*/

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;

// --- Parameters ---
#pragma parameter g_profile   "CRT Profile: 0:Off, 1:NTSC, 2:PAL, 3:PVM, 4:J-NTSC" 0.0 0.0 4.0 1.0
#pragma parameter g_r         "Red Weight"             1.0  0.0  2.0  0.02
#pragma parameter g_g         "Green Weight"           1.0  0.0  2.0  0.02
#pragma parameter g_b         "Blue Weight"            1.0  0.0  2.0  0.02
#pragma parameter g_glow      "Soft Glow Strength"     0.15 0.0  0.5  0.05
#pragma parameter g_lift      "OLED Black Depth"       0.03 0.0  0.2  0.01
#pragma parameter g_vibr      "Smart Vibrance"         0.35 0.0  1.5  0.05
#pragma parameter g_cntrst    "Sigmoidal Contrast"     0.1  0.0  1.0  0.05
#pragma parameter g_pivot     "Contrast Pivot"         0.5  0.0  1.0  0.05

#ifdef PARAMETER_UNIFORM
uniform float g_profile, g_r, g_g, g_b, g_glow, g_lift, g_vibr, g_cntrst, g_pivot;
#endif

void main() {
    vec3 col = texture2D(Texture, vTexCoord).rgb;

    // 1. Regional Profile System (تصحيح حرارة الألوان حسب الإقليم)
    vec3 prof = vec3(1.0);
    if (g_profile > 0.5) {
        if (g_profile < 1.5)      prof = vec3(1.10, 0.95, 0.90); // NTSC (ميل للدفء)
        else if (g_profile < 2.5) prof = vec3(0.95, 1.05, 0.95); // PAL (متعادل خضراوي خفيف)
        else if (g_profile < 3.5) prof = vec3(1.00, 1.05, 1.10); // PVM (احترافي مائل للزرقة)
        else                      prof = vec3(0.92, 0.97, 1.15); // J-NTSC (بارد جداً - النمط الياباني)
    }
    
    // 2. RGB Gain & Profile Application
    col *= prof * vec3(g_r, g_g, g_b);

    // 3. OLED Black Depth (تحسين عمق اللون الأسود لشاشات الـ OLED)
    col = max(col - g_lift, 0.0) / (1.0 - g_lift);

    // 4. Soft Glow (إضاءة ناعمة للمناطق الساطعة فقط)
    if (g_glow > 0.01) {
        vec3 glow_effect = smoothstep(0.4, 1.0, col);
        col += glow_effect * g_glow;
    }

    // 5. Smart Vibrance (زيادة حيوية الألوان الباهتة دون تشبع الألوان القوية)
    float max_c = max(col.r, max(col.g, col.b));
    float min_c = min(col.r, min(col.g, col.b));
    float sat_mask = (max_c - min_c) / (max_c + 1.0e-5);
    col = mix(col, vec3(max_c), g_vibr * (1.0 - sat_mask));

    // 6. Sigmoidal Contrast (تباين سينمائي يحافظ على التفاصيل)
    col = (col - g_pivot) * (g_cntrst + 1.0) + g_pivot;

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif