// RetroArch Color Pop Shader (GLSL)
// Description: Isolates a specific target color and desaturates the rest of the image.
// Author: Assistant (Inspired by the concept of "Color Pop")

// --- RETROARCH PARAMETERS ---
// Target Hue to keep (0 = Red, 120 = Green, 240 = Blue)
#pragma parameter COLOR_POP_HUE "Color Pop Target Hue" 0.0 0.0 360.0 1.0
// How wide the target color range is. (Higher means more colors are considered 'popping')
#pragma parameter COLOR_POP_TOLERANCE "Color Pop Tolerance" 1.0 1.0 100.0 1.0
// Level of desaturation for the background (1.0 = fully grayscale)
#pragma parameter COLOR_POP_DESAT_LEVEL "Color Pop Background Darkness" 1. 0.0 1.0 0.01
// Extra saturation boost for the isolated color (1.0 = normal)
#pragma parameter COLOR_POP_SAT_BOOST "Color Pop Boost (Keep Color)" 1.2 1.0 2.0 0.05

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

#ifdef PARAMETER_UNIFORM
uniform float COLOR_POP_HUE;
uniform float COLOR_POP_TOLERANCE;
uniform float COLOR_POP_DESAT_LEVEL;
uniform float COLOR_POP_SAT_BOOST;
#else
#define COLOR_POP_HUE 0.0 
#define COLOR_POP_TOLERANCE 15.0
#define COLOR_POP_DESAT_LEVEL 0.9
#define COLOR_POP_SAT_BOOST 1.2
#endif

// Helper to calculate hue (0.0 - 1.0)
float getHue(vec3 c) {
    float minVal = min(c.r, min(c.g, c.b));
    float maxVal = max(c.r, max(c.g, c.b));
    float d = maxVal - minVal;
    if (d < 0.0001) return 0.0; // Grayscale has no hue
    float h = 0.0;
    if (c.r == maxVal) h = (c.g - c.b) / d;
    else if (c.g == maxVal) h = 2.0 + (c.b - c.r) / d;
    else h = 4.0 + (c.r - c.g) / d;
    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

void main() {
    // Sample the sharp input texture (retaining raw pixel aesthetic)
    vec3 res = texture2D(Texture, uv).rgb;

    // Convert target hue from degrees to 0.0 - 1.0 range
    float targetHue = COLOR_POP_HUE / 360.0;

    // Get the current pixel's hue
    float pixelHue = getHue(res);

    // Calculate the shortest distance between the two hues on the color wheel
    float dist = abs(pixelHue - targetHue);
    if (dist > 0.5) dist = 1.0 - dist;

    // Convert tolerance parameter from degrees to a comparable 0.0 - 1.0 range
    float normTolerance = COLOR_POP_TOLERANCE / 180.0; // 180 makes the slider intuitive

    // Create a sharp step mask (no smoothing) to isolate raw pixels
    // If dist > tolerance, mask is 0 (keep color). If dist <, mask is 1 (grayscale).
    float popMask = step(normTolerance, dist); 
    popMask = 1.0 - popMask; // Invert to: 1 (keep color), 0 (grayscale).

    // Calculate grayscale value
    float grayVal = dot(res, vec3(0.299, 0.587, 0.114));
    vec3 grayscale = vec3(grayVal);

    // Define the colors for mixing:
    // BoostedColor: The isolated color, made extra vibrant.
    vec3 boostedColor = res * COLOR_POP_SAT_BOOST;
    // DesatBase: The rest of the image, mixed towards grayscale.
    vec3 desatBase = mix(res, grayscale, COLOR_POP_DESAT_LEVEL);
    
    // Mix the two (colorful subject vs desaturated background) using the mask
    vec3 finalRes = mix(desatBase, boostedColor, popMask);

    gl_FragColor = vec4(finalRes, 1.0);
}
#endif