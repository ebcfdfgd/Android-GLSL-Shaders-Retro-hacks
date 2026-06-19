#version 110

/* =====================================================
    DEBUGGING HEATMAP WITH ON/OFF SWITCH
===================================================== */
#pragma parameter DEBUG_MODE "Enable Debug Heatmap" 1.0 0.0 1.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

uniform float DEBUG_MODE;

void main() {
    // Get the original pixel color
    vec3 res = texture2D(Texture, uv).rgb;

    // 1. Calculate Luminance (Brightness)
    float luma = dot(res, vec3(0.2126, 0.7152, 0.0722));

    // 2. Calculate Saturation
    float max_channel = max(res.r, max(res.g, res.b));
    float min_channel = min(res.r, min(res.g, res.b));
    float saturation = (max_channel - min_channel) / (max_channel + 0.000001);

    // 3. Heatmap Visualization Logic
    vec3 debug_color = res;

    // Check if Debug Mode is turned ON
    if (DEBUG_MODE > 0.5) {
        // Danger: Highlights Clipping (Pure Red)
        if (luma > 0.98) {
            debug_color = vec3(1.0, 0.0, 0.0);
        } 
        // Danger: Shadows Crushing (Pure Blue)
        else if (luma < 0.02) {
            debug_color = vec3(0.0, 0.0, 1.0);
        } 
        // Danger: Extreme Oversaturation (Pure Magenta)
        else if (saturation > 0.9) {
            debug_color = vec3(1.0, 0.0, 1.0);
        } 
        // Warning: High Saturation (Green Tint)
        else if (saturation > 0.75) {
            debug_color = mix(res, vec3(0.0, 1.0, 0.0), 0.5);
        }
    }

    // Output the final debugged color
    gl_FragColor = vec4(debug_color, 1.0);
}
#endif