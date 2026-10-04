#version 450

/* ULTIMATE-HYBRID-LIGHT (L1: Overlay, L2: Multi)
    - REMOVED: Game Zoom logic.
    - KEPT: Dual Layering (Overlay & Multiply).
    - PERFORMANCE: Maximum speed for standard view.
*/

// --- PARAMETERS ---

#pragma parameter BRIGHT_BOOST "Final Bright Boost" 1.2 1.0 5.0 0.05
#pragma parameter overlay_str "L1 PNG Intensity (Overlay)" 0.35 0.0 1.0 0.05
#pragma parameter png_width "L1 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 4.0 1.0 1024.0 1.0
#pragma parameter overlay_str2 "L2 PNG Intensity (Multi)" 0.20 0.0 1.0 0.05
#pragma parameter png_width2 "L2 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height2 "L2 PNG Height" 4.0 1.0 1024.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BRIGHT_BOOST;
	float overlay_str;
	float png_width;
	float png_height;
	float overlay_str2;
	float png_width2;
	float png_height2;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 TEX0;
layout(location = 1) out vec2 screen_scale;

void main() {
    gl_Position = global.MVP * Position;
    TEX0 = TexCoord; 
    screen_scale = params.SourceSize.xy / params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 TEX0;
layout(location = 1) in vec2 screen_scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OverlayTexture;
layout(set = 0, binding = 4) uniform sampler2D OverlayTexture2;

// دالة الـ Overlay
vec3 overlay_logic(vec3 a, vec3 b) {
    return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
}

void main() {
    // إحداثيات للشاشة (تستخدم للطبقات)
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] DIRECT SAMPLING (Standard View - No Zoom)
    vec3 res = texture(Source, TEX0).rgb;

    // [2] Layer 1 (Overlay Mode)
    if (params.overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * params.OutputSize.x / (params.png_width)), 
                            fract(mP.y * params.OutputSize.y / (params.png_height)));
        vec3 png1 = texture(OverlayTexture, maskUV1).rgb;
        
        vec3 ovl1 = overlay_logic(res, png1);
        res = mix(res, clamp(ovl1, 0.0, 1.0), params.overlay_str);
    }

    // [3] Layer 2 (Multiply Mode)
    if (params.overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * params.OutputSize.x / (params.png_width2)), 
                            fract(mP.y * params.OutputSize.y / (params.png_height2)));
        vec3 png2 = texture(OverlayTexture2, maskUV2).rgb;
        
        res = mix(res, res * png2, params.overlay_str2);
    }

    // [4] Final Brightness Boost
    res *= params.BRIGHT_BOOST;

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
