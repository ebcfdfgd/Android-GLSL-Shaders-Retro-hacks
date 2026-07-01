/* CUBIC COORDINATE WARPING SHADER
   - Feature: Sharp-Bilinear Y-Axis Scaling.
   - Optimization: Branchless math, parameterized sharpness.
   - Logic: Keeps pixel centers sharp while smoothing out the transitions.
*/

#pragma parameter WARP_SHARP "Y-Axis Warp Sharpness" 4.0 1.0 10.0 0.10

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
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float WARP_SHARP;
#endif

void main() {
    // 1. Transform normalized UV to texture pixel coordinates for the Y-axis
    float ogl2pos_y = uv.y * TextureSize.y;

    // 2. Locate the exact center of the nearest pixel row
    float near = floor(ogl2pos_y) + 0.5;
    
    // 3. Calculate distance from the current coordinate to the pixel center
    float f = ogl2pos_y - near;
    
    // 4. Apply the Cubic Warping equation using the dynamic WARP_SHARP parameter
    float y = (near + WARP_SHARP * f * f * f) / TextureSize.y;
    
    // 5. Reconstruct the new coordinate (X stays pristine, Y gets warped)
    vec2 pos = vec2(uv.x, y);
    
    // 6. Sample the texture with hardware linear filtering applied smartly
    vec3 pixelColor = texture2D(Texture, pos).rgb;

    gl_FragColor = vec4(pixelColor, 1.0);
}
#endif