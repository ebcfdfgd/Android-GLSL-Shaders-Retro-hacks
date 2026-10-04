#version 450

/*
    Ben-Day Dots Standalone Shader (Physical Screen Pixels)
    -------------------------------------------------------
*/

#pragma parameter DOT_DENSITY  "Dot Grid Size (px)"     6.0  3.0 16.0 0.5
#pragma parameter DOT_ANGLE    "Dot Grid Angle (deg)"   15.0 0.0 90.0 5.0
#pragma parameter DOT_STRENGTH "Dot Shading Strength"   0.85 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float DOT_DENSITY;
	float DOT_ANGLE;
	float DOT_STRENGTH;
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

const vec3 Y = vec3(0.299, 0.587, 0.114);

// Ben-Day Dot Pattern Generator
float benDayDot(vec2 fragCoord, float density, float angleDeg, float darkness) {
    float angle = radians(angleDeg);

    vec2 rotated = vec2(
        fragCoord.x * cos(angle) - fragCoord.y * sin(angle),
        fragCoord.x * sin(angle) + fragCoord.y * cos(angle)
    );

    vec2 cell = mod(rotated, density) - density * 0.5;
    float dist = length(cell);
    float radius = darkness * (density * 0.5);

    return 1.0 - smoothstep(
        radius - 1.0,
        radius + 1.0,
        dist
    );
}

void main() {
    vec3 color = texture(Source, uv).rgb;

    // Ben-Day Dots Shading Overlay locked to physical screen resolution (OutputSize)
    float finalLum = dot(color, Y);
    float darkness = 1.0 - finalLum;
    
    vec2 screenCoord = uv * params.OutputSize.xy;
    float dotPattern = benDayDot(
        screenCoord,
        params.DOT_DENSITY,
        params.DOT_ANGLE,
        darkness
    );

    color = mix(
        color,
        vec3(0.0),
        dotPattern * params.DOT_STRENGTH * 0.4
    );

    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

