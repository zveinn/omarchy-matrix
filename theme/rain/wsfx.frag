#version 440
// Workspace switch "code curtain": ragged columns of falling glyphs, each on an
// opaque near-black strip, pour down over the screen and drain off the bottom.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float prog;   // 0..1
    float cell;
    float atlasCols;
    float atlasCount;
    vec2 res;
};
layout(binding = 1) uniform sampler2D atlas;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 cr = floor(px / cell);
    float c = cr.x;
    float delay = h(vec2(c, 1.0)) * 0.12;
    float t = clamp((prog - delay) / 0.88, 0.0, 1.0);
    float L = res.y * (0.45 + 0.55 * h(vec2(c, 2.0)));          // strip length
    float head = t * (res.y + L);                                 // head position
    float d = head - px.y;                                        // distance above head
    if (t <= 0.0 || d < 0.0 || d > L) { fragColor = vec4(0.0); return; }
    float g = 1.0 - d / L;
    float tick = floor(time * (10.0 + h(cr) * 16.0));
    float idx = floor(h(cr + tick * 0.618) * atlasCount);
    vec2 lu = fract(px / cell); lu.x = 1.0 - lu.x;
    vec2 uv = (vec2(mod(idx, atlasCols), floor(idx / atlasCols)) + lu) / atlasCols;
    float a = texture(atlas, uv).a * (0.25 + 0.75 * pow(g, 1.3));
    bool isHead = d < cell;
    vec3 col = isHead ? vec3(0.88, 1.0, 0.92) : vec3(0.0, 1.0, 0.255) * (0.55 + 0.45 * g);
    vec3 bg = vec3(0.004, 0.02, 0.008);
    // tail of the strip turns translucent so the drain reveals smoothly
    float bga = smoothstep(0.0, 0.25, g);
    vec3 rgb = mix(bg * bga, col, a);
    fragColor = vec4(rgb, max(bga, a)) * qt_Opacity;
}
