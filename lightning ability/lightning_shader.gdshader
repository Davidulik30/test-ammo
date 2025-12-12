shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_test_disabled;

// Параметры шейдера
uniform float glow_intensity : hint_range(0.0, 3.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 3.0;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec3 base_color : source_color = vec3(0.3, 0.6, 1.0);
uniform vec3 bright_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float edge_glow : hint_range(0.0, 2.0) = 1.5;
uniform float branch_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float branch_width : hint_range(0.0, 0.3) = 0.15;
uniform float flow_speed : hint_range(0.0, 10.0) = 5.0;
uniform float flow_width : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	// Получаем координаты текстуры вдоль линии
	float uv_progress = UV.x;
	float uv_width = UV.y;
	
	// Центральная полоса молнии - сильнее к центру
	float center_line = 1.0 - abs(uv_width - 0.5) * 2.0;
	center_line = pow(center_line, 2.0);
	
	// Пульсирующий эффект - более резкая пульсация
	float pulse = pow(sin(TIME * pulse_speed) * 0.5 + 0.5, 2.0);
	pulse = mix(0.3, 1.0, pulse); // Минимум 0.3, максимум 1.0 для резкости
	
	// Мерцание
	float flicker = 1.0 - flicker_intensity * abs(sin(TIME * pulse_speed * 5.0));
	
	// Волновой эффект вдоль линии
	float wave = sin(uv_progress * 10.0 + TIME * pulse_speed * 2.0) * 0.3 + 0.7;
	
	// ===== ЭФФЕКТ ТЕЧЕНИЯ МОЛНИИ - ОТ НАЧАЛА К КОНЦУ =====
	// Создаем движущуюся полосу света вдоль молнии (от 0 к 1)
	float flow_position = mod(uv_progress - TIME * flow_speed, 1.0);
	float flow = smoothstep(flow_position + flow_width, flow_position, uv_progress) 
	           - smoothstep(flow_position, flow_position - flow_width, uv_progress);
	flow = clamp(flow, 0.0, 1.0);
	
	// ===== РАЗВЕТВЛЕНИЯ ПО ВСЕЙ МОЛНИИ =====
	float branches = 0.0;
	
	// Первичные боковые ветвления (волны по сторонам)
	for (int i = 1; i <= 4; i++) {
		float start = float(i - 1) * 0.25;
		float end = float(i) * 0.25;
		
		if (uv_progress > start) {
			float branch_segment = (uv_progress - start) / (end - start + 0.1);
			branch_segment = clamp(branch_segment, 0.0, 1.0);
			
			// Боковые ветви слева и справа
			float left_wave = sin(uv_progress * 15.0 + TIME * pulse_speed) * 0.15;
			float left_dist = abs(uv_width - 0.2 + left_wave);
			float left_branch = smoothstep(0.08, 0.0, left_dist);
			left_branch *= sin(branch_segment * 3.14159) * 0.5;
			left_branch *= (0.6 + sin(TIME * pulse_speed + float(i)) * 0.4);
			branches += left_branch * branch_intensity * 0.6;
			
			float right_wave = cos(uv_progress * 15.0 + TIME * pulse_speed) * 0.15;
			float right_dist = abs(uv_width - 0.8 + right_wave);
			float right_branch = smoothstep(0.08, 0.0, right_dist);
			right_branch *= sin(branch_segment * 3.14159) * 0.5;
			right_branch *= (0.6 + sin(TIME * pulse_speed - float(i)) * 0.4);
			branches += right_branch * branch_intensity * 0.6;
		}
	}
	
	// Дополнительные микро-ветвления по всей длине
	float micro_branches = 0.0;
	float micro_pattern = sin(uv_progress * 30.0 + TIME * pulse_speed * 3.0);
	if (micro_pattern > 0.7) {
		float micro_offset = sin(uv_progress * 50.0) * 0.12;
		float micro_dist_top = abs(uv_width - 0.55 + micro_offset);
		float micro_dist_bot = abs(uv_width - 0.45 + micro_offset);
		
		float micro_top = smoothstep(0.04, 0.0, micro_dist_top);
		float micro_bot = smoothstep(0.04, 0.0, micro_dist_bot);
		
		micro_branches = (micro_top + micro_bot) * 0.4;
	}
	
	branches += micro_branches * branch_intensity * 0.5;
	
	// Комбинируем основную молнию с разветвлениями
	float total_intensity = center_line + branches;
	total_intensity *= pulse * flicker * wave;
	
	// Цвет молнии - смешиваем базовый и яркий цвет
	vec3 color = mix(base_color, bright_color, total_intensity);
	
	// Выходной цвет
	vec3 final_color = color * glow_intensity * total_intensity;
	
	ALBEDO = final_color;
	// Повышенное свечение - в 4 раза ярче, плюс дополнительное от течения
	EMISSION = final_color * (4.0 + flow * 3.0);
	ALPHA = max(0.5, total_intensity);
}


