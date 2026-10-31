shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// 程序化窗户：按世界坐标切网格，无需贴图
uniform vec3 base_color : source_color = vec3(0.5, 0.5, 0.52);
uniform vec3 window_color : source_color = vec3(0.10, 0.16, 0.24);
uniform vec3 glow_color : source_color = vec3(1.0, 0.86, 0.58);
uniform float win_x = 3.2;
uniform float win_y = 3.6;
uniform float win_ratio : hint_range(0.1, 0.95) = 0.55;
uniform float base_y = 1.3;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float rough_base : hint_range(0.0, 1.0) = 0.9;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float win = 0.0;
	if (abs(wnrm.y) < 0.5) {
		float u = (abs(wnrm.z) > abs(wnrm.x)) ? wpos.x : wpos.z;
		float cu = fract(u / win_x);
		float cv = fract(wpos.y / win_y);
		float lo = (1.0 - win_ratio) * 0.5;
		float hi = 1.0 - lo;
		float m = step(lo, cu) * step(cu, hi);
		float m2 = step(0.30, cv) * step(cv, 0.84);
		win = m * m2 * step(base_y, wpos.y);
	}
	ALBEDO = mix(base_color, window_color, win * 0.92);
	ROUGHNESS = mix(rough_base, 0.30, win);
	METALLIC = mix(0.0, 0.10, win);
	EMISSION = glow_color * win * night * 1.25;
}
