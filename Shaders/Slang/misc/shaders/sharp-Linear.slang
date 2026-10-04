#version 450

/* CUBIC COORDINATE WARPING SHADER
   - Feature: Sharp-Bilinear Y-Axis Scaling.
   - Optimization: Branchless math, parameterized sharpness.
   - Logic: Keeps pixel centers sharp while smoothing out the transitions.
*/

#pragma parameter WARP_SHARP "Y-Axis Warp Sharpness" 4.0 1.0 10.0 0.10

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float WARP_SHARP;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 uv;

void main() {
    uv = TexCoord;
    gl_Position = global.MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // 1. Transform normalized UV to texture pixel coordinates for the Y-axis
    float ogl2pos_y = uv.y * params.SourceSize.y;

    // 2. Locate the exact center of the nearest pixel row
    float near = floor(ogl2pos_y) + 0.5;
    
    // 3. Calculate distance from the current coordinate to the pixel center
    float f = ogl2pos_y - near;
    
    // 4. Apply the Cubic Warping equation using the dynamic WARP_SHARP parameter
    float y = (near + params.WARP_SHARP * f * f * f) / params.SourceSize.y;
    
    // 5. Reconstruct the new coordinate (X stays pristine, Y gets warped)
    vec2 pos = vec2(uv.x, y);
    
    // 6. Sample the texture with hardware linear filtering applied smartly
    vec3 pixelColor = texture(Source, pos).rgb;

    FragColor = vec4(pixelColor, 1.0);
}
