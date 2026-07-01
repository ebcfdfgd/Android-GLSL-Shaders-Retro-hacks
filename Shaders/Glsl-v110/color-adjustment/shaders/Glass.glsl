#version 110

/* 777-CRT-ANALOG-MASTER - PURE GLASS ONLY PASS (NO POW)
    - FEATURES: Fresnel Edge (Linear), Top-Left Specular, and Ambient Surface Gloss.
    - FLAT: No curvature, pure flat glass simulation over original game colors.
*/

// --- GLASS PARAMETERS ---
#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float GLASS_STR, BORDER_GLOSS;
#endif

void main() {
    // 1. Fetch Original Game Pixels (No color/bloom alterations)
    vec3 col = texture2D(Texture, uv).rgb;

    // 2. Setup Glass Coordinates
    vec2 sc = TextureSize / InputSize;
    vec2 p_glass = (uv * sc) - 0.5;
    float r2_glass = dot(p_glass, p_glass);

    // 3. Fresnel Effect (Linearized without pow function)
    float fresnel = r2_glass * r2_glass * 4.84 * BORDER_GLOSS;

    // 4. Specular Highlight (Simulated bulb reflection at top-left)
    float spec = smoothstep(0.4, 0.0, length(p_glass - vec2(-0.35, 0.35)));
    spec *= 0.15 * GLASS_STR;

    // 5. Ambient Gloss (Center-out surface glow)
    float gloss = (1.0 - length(p_glass)) * 0.05 * GLASS_STR;

    // 6. Final Composite & Safety Clamp
    vec3 final_color = col + fresnel + spec + gloss;
    gl_FragColor = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
#endif