module main

import gg
import iui as ui
import os
import gx

fn codebox_text_change(mut win ui.Window, box ui.Textbox) {
	mut saved := false
	if box.ctrl_down {
		if box.last_letter == 's' {
			println('SAVE REQUEST!')
			do_save(mut win)
			saved = true
		}
	}

	// Text Suggestions
	mut indx := box.carrot_top + 1
	mut mtxt := ''
	spl := box.text.split_into_lines()
	if (indx - 1) < spl.len {
		mtxt = spl[indx - 1]
	}
	mtxt = mtxt.substr_ni(0, box.carrot_left)
	mut splt := mtxt.split(' ')
	fin := splt[splt.len - 1]
	win.extra_map['fin'] = fin

	// v -check-syntax
	file := get_tab_name(mut win)
	// println(file)
	if file.ends_with('.v') && saved {
		go cmd_exec(mut win, file, &box)
	}
}

struct Hovermess {
	ui.Component_A
pub mut:
	win   &ui.Window
	text  string
	num   int
	off_y int
	box   &ui.Textbox
}

fn (mut this Hovermess) draw() {
	mut mid := (this.x + (this.width / 2))
	mut midy := (this.y + (this.height / 2))

	mut num := this.num - this.box.scroll_i
	this.y = this.off_y + (ui.text_height(this.win, '1A{') * num - 1) - (ui.text_height(this.win,
		'1A{') / 2)

	if this.y < this.off_y {
		return
	}

	com := &ui.Tabbox(this.win.get_from_id('main-tabs'))
	if com.kids[com.active_tab].len > 1 {
		// Welcome Tab
		return
	}
	for mut kid in com.kids[com.active_tab] {
		if mut kid is ui.Textbox {
			if kid != this.box {
				return
			}
		}
	}

	mut bg := gx.rgb(255, 204, 0)
	if this.text.contains('error:') {
		bg = gx.rgb(204, 51, 0)
	}

	this.win.draw_bordered_rect(this.x, this.y, this.width, this.height, 2, bg, this.win.theme.text_color)

	if (ui.abs(mid - this.win.mouse_x) < (this.width / 2))
		&& (ui.abs(midy - this.win.mouse_y) < (this.height / 2)) {
		off := 8
		this.win.draw_bordered_rect(this.x + this.width, this.y,
			ui.text_width(this.win, this.text) + (2 * off), this.height, 2, this.win.theme.background,
			this.win.theme.text_color)
		this.win.gg.draw_text(this.x + this.width + off, this.y, this.text, gx.TextCfg{
			size: this.win.font_size
			color: this.win.theme.text_color
		})
	}

	twidth := ui.text_width(this.win, this.num.str()) / 2
	this.win.gg.draw_text(this.x + (this.width / 2) - twidth, this.y, this.num.str(),
		gx.TextCfg{
		size: this.win.font_size
		color: this.win.theme.text_color
	})
}

fn hover(mut win ui.Window) Hovermess {
	return Hovermess{
		win: win
		box: 0
	}
}

fn cmd_exec(mut win ui.Window, file string, box &ui.Textbox) {
	vexe := get_v_exe(mut win)

	res := os.execute(vexe + ' -check-syntax ' + file)
	out := res.output

	lines := out.split_into_lines()
	mut l2 := []string{}
	for line in lines {
		if !line.contains(' |') {
			l2 << line
		}
	}

	win.components = win.components.filter(mut it !is Hovermess)

	mut tx := 0
	mut ty := 0
	mut tbox := ui.textbox(win, '')
	for mut com in win.components {
		if mut com is ui.Tabbox {
			tx = com.x
			ty = com.y
			for mut kid in com.kids[com.active_tab] {
				if mut kid is ui.Textbox {
					tbox = kid
				}
			}
		}
	}

	for line in l2 {
		// println(line)
		num := line.split('.v:')[1].split(':')[0]
		mut hove := hover(mut win)
		hove.num = num.int()
		hove.z_index = 100
		hove.x = tx + tbox.x
		hove.box = tbox
		csy := 20
		hove.off_y = ty + csy + box.y
		hove.y = ty + csy + box.y + (ui.text_height(win, '1A{') * (num.int()) - 1) - (ui.text_height(win,
			'1A{') / 2)
		hove.width = 20
		hove.height = ui.text_height(win, '1A{')
		hove.text = line.split('.v:')[1]
		win.add_child(hove)
	}
}

fn get_tab_name(mut win ui.Window) string {
	for mut com in win.components {
		if mut com is ui.Tabbox {
			return com.active_tab
		}
	}
	return '.'
}

fn on_box_draw_1(mut win ui.Window, mut box ui.Textbox, tx int, ty int) {
	fin := win.extra_map['fin']

	mut is_fin := false
	for str in all_vlib_mod(mut win) {
		if fin.starts_with(str + '.') {
			is_fin = true
		}
	}

	if is_fin {
		mut indx := box.carrot_top + 1
		mut mtxt := ''
		spl := box.text.split_into_lines()
		if (indx - 1) < spl.len {
			mtxt = spl[indx - 1]
		}
		mtxt = mtxt.substr_ni(0, box.carrot_left)
		mut splt := mtxt.split(' ')

		last_ym := win.gg.text_height('A{')
		mut lt := last_ym * (box.carrot_top) - (last_ym * box.scroll_i)
		mut lw := 0
		mut splt_i := 0
		mut aft := ''
		mut mod := fin.split('.')[0]
		for atxt in splt {
			if splt_i == splt.len - 1 {
				alen := (atxt.last_index('.') or { -1 }) + 1
				aft = atxt.substr_ni(alen, atxt.len)
				lw += 5
			}
			lw += ui.text_width(win, atxt + ' ')
			splt_i++
		}
		sug := match_fn(mut win, mod, aft)
		lw = (lw - ui.text_width(win, ' ')) + (box.padding_x - 4)

		mut r := ((win.theme.text_color.r / 2) + win.theme.background.r) / 2
		color := gx.rgb(r, r, r)

		win.gg.draw_text(box.x + tx + lw, ty + box.y + lt + 26, sug.replace_once(aft,
			''), gx.TextCfg{
			size: win.font_size
			color: color
		})
	}
}

fn match_fn(mut win ui.Window, mod string, str string) string {
	if str.len <= 0 {
		return ''
	}
	strs := find_all_fn_in_vlib(mut win, mod)

	for st in strs {
		if st == str {
			return st
		}
	}

	for st in strs {
		if st.starts_with(str) {
			return st
		}
	}
	return ''
}

fn all_vlib_mod(mut win ui.Window) []string {
	id := 'vlib'
	if id in win.extra_map {
		return win.extra_map[id].split(' ')
	}

	mut arr := []string{}
	mut vlib := os.dir(get_v_exe(mut win)).replace('\\', '/') + '/vlib'
	for file in os.ls(vlib) or { [''] } {
		arr << file
	}
	win.extra_map[id] = arr.join(' ')
	return arr
}

fn find_all_fn_in_vlib(mut win ui.Window, mod string) []string {
	id := 'sug-' + mod
	if id in win.extra_map {
		return win.extra_map[id].split(' ')
	}

	mut arr := []string{}
	mut vlib := os.dir(get_v_exe(mut win)).replace('\\', '/') + '/vlib'
	mut mod_dir := vlib + '/' + mod
	for file in os.ls(mod_dir) or { [''] } {
		lines := os.read_lines(mod_dir + '/' + file) or { [''] }
		for line in lines {
			if line.starts_with('pub fn') && !line.starts_with('pub fn (') {
				name := line.split('pub fn ')[1].split('(')[0]
				arr << name
			}
		}
	}
	win.extra_map[id] = arr.join(' ')
	return arr
}

fn get_v_exe(mut win ui.Window) string {
	mut conf := get_config(mut win)
	mut saved := conf.get_or_default('v_exe').replace('{user_home}', '~')
	saved = saved.replace('~', os.home_dir().replace('\\', '/'))

	if saved.len <= 0 {
		mut vexe := 'v'
		$if windows {
			vexe = 'v.exe'
		}
		if 'VEXE' in os.environ() {
			vexe = os.environ()['VEXE'].replace('\\', '/')
		}
		vexe = vexe.replace(os.home_dir().replace('\\', '/'), '~')
		conf.set('v_exe', vexe)
		conf.save()
		return vexe
	} else {
		return saved
	}
}