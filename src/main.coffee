header = """
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
	# SiraLime teamcards renderer v0.6
	# Developed in 2019 by Guevara-chan
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

"""
Function::getter = (name, proc)	-> Reflect.defineProperty @prototype, name, {get: proc, configurable: true}
Function::setter = (name, proc)	-> Reflect.defineProperty @prototype, name, {set: proc, configurable: true}
clr = require('clr').init assemblies: 'System|mscorlib|System.Drawing|System.Windows.Forms|PresentationCore'.split '|'
Object.assign global, namespace for namespace in [System.Drawing]

#.{ [Classes]
class SiralimData
	source_cache = "cache.txt"

	# --Methods goes here.
	constructor: (src = System.IO.File.ReadAllText source_cache) ->
		# Main parser.
		feed = src.split('\r\n')
		if feed[0] is '========== CHARACTER ==========' # If header is valid...
			System.IO.File.WriteAllText source_cache, src, System.Text.Encoding.ASCII
			# Parsing player section.
			@player = @player_data feed.splice(1, feed.indexOf "========== CREATURES ==========")
			# Parsing creature sections.
			@team = while feed.length > 2
				@crit_data feed.splice(1, 1 + feed.indexOf "------------------------------")
		else throw new Error "Invalid export data provided."

	@capitalize: (txt) ->
		txt[0].toUpperCase() + txt[1..]

	get: get =
		field: (feed, field) ->
			matcher = new RegExp field + ": (.*)"
			idx = feed?.findIndex((elem) -> matcher.test elem)
			feed.splice(idx, 1)[0].match(matcher).pop() if idx != -1		
		list: (feed, matcher) ->
			get.rawlist feed, matcher, (x) -> x.match(matcher)[1]
		rawlist: (feed, matcher, mapper = (x) => x.match(matcher)) ->
			feed.filter((x) -> matcher.test x).map(mapper)

	player_data: (fragment) ->
		# Init setup.
		headline	= fragment[0].match(/([\w\s]+), Level (\d*) (\w*) Mage/)
		perkfinder	= /(.*) \(Rank (\d*) \/ (\d*)\)/
		achievments	= @get.field(fragment, "Achievement Points").split(' ')
		# Title & name analyzis.
		parts	= headline[1].split ' '
		name	= (if parts.length > 2 and parts[1] is "the" then parts.splice(0, 1) else parts.pop())
		title	= parts.join(' ')
		# Actual extraction.
		title:		title
		name:		name
		level:		BigInt headline[2]
		class:		headline[3]
		played:		@get.field(fragment, "Time Played")
		version:	@get.field(fragment, "Game Version")
		dpoints:	BigInt @get.field(fragment, "Total Deity Points")
		runes:		@get.list(fragment, /(\w*) Rune:/)
		achievs:	{got: parseInt(achievments[0]), total: parseInt(achievments[2]), progress: achievments[3]}
		perks:		fragment.filter((x) -> perkfinder.test x).map (x) ->
			{name: (arr = perkfinder.exec(x)[1..3])[0], lvl: parseInt(arr[1]), max: parseInt(arr[2])}

	crit_data: (fragment) ->
		# Init setup.
		[stats, naming, spec]	= [{}, fragment[0].split(' '), fragment[1].match /(.*) \/ (.*)/]
		art_start				= fragment.findIndex (x) -> x.startsWith "Artifact: "
		art_data = if art_start isnt -1 then fragment.splice(art_start,fragment.indexOf("",art_start)-art_start) else []
		# Other stats.
		singular:	if naming[naming.length-1] is '(Singular)'	then naming.pop(); true else false
		nether:		if naming[naming.length-1] is '(Nether)'	then naming.pop(); true else false
		name:		name = naming[2..].join(' ')
		level:		BigInt naming[1]
		kind:		spec[1]
		class:		spec[2]
		sprite:		@load_sprite(name)
		aura:		@get.field(fragment, "Nether Aura: Nether Aura") ? ""
		nethtraits:	@get.list(fragment, /Nether Trait: (.*)/)
		gems:		for gem in @get.rawlist(fragment, /Gem of (.*) \(Mana Cost: (\d*)\)(?: \| )?(.*)/)
			[spoof, name, cost, mods] = gem
			##################################
			{name: name, cost: cost, mods: mods.split ', '}
			##################################
		stats:		(Object.assign(stats,
			{[stat]: BigInt @get.field fragment, SiralimData.capitalize(stat) + '( \\(.*\\))?'}) for stat in [
				'health', 'mana', 'attack', 'intelligence', 'defense', 'speed'])[0]
		art:
			name:	@get.field(art_data, "Artifact") ? ""
			trait:	@get.field(art_data, "Trait") ? ""
			mods:	art_data

	load_sprite: (crit_name) ->
		cache_file = "res\\#{crit_name}.png"
		try return new Bitmap cache_file
		client = new System.Net.WebClient()
		stream = client.
			OpenRead "https://raw.githubusercontent.com/Guevara-chan/SiraLime/master/res/#{encodeURI crit_name}.png"
		bmp = new Bitmap(stream)
		bmp.Save(cache_file, Imaging.ImageFormat.Png)
		return bmp
# -------------------	
class Render
	color_code:
		Death:	Color.Magenta
		Chaos:	Color.Crimson 
		Nature:	Color.Chartreuse
		Life:	Color.GhostWhite
		Sorcery:Color.Cyan
	TR = System.Windows.Forms.TextRenderer

	# --Methods goes here.
	constructor: (s3data, pipe, show_off, dest = 'last.png') ->
		# Init setup.
		customfonts = new Text.PrivateFontCollection()
		@fonts		=  {}
		for font, idx in ["Neue", "Dosis", "Sylfaen"]
			customfonts.AddFontFile("res/fonts/#{font}.ttf")
			@fonts[font] =	customfonts.Families.GetValue(idx)
		# Actual render.
		@bmp		= show_off @render pipe s3data
		@save(dest) if @bmp

	txt: txt =
		width: (txt, font) ->
			TR.MeasureText(txt, font).Width
		height: (txt, font) ->
			TR.MeasureText(txt, font).Height

	draw:
		block: (out, x, y, width, height, pen, brush) ->
			out.FillRectangle brush, x, y, width, height
			out.DrawRectangle pen, x, y, width, height
		text: (out, text, font, x, y, color) ->
			TR.DrawText out, text, font, new Point(1 + x - txt.width(text, font) / 2, y), color

	alpha_blt: (out, img, x, y, width, height, a = 1, flip) ->
		cm = new Imaging.ColorMatrix()
		cm.Matrix33 = a
		ia = new Imaging.ImageAttributes()
		ia.SetColorMatrix(cm, Imaging.ColorMatrixFlag.Default, Imaging.ColorAdjustType.Bitmap)
		lock = img.LockBits(new Rectangle(0, 0, img.Width, img.Height), Imaging.ImageLockMode.ReadOnly,
			Imaging.PixelFormat.Format24bppRgb)
		asprite = new Bitmap(img.Width, img.Height, lock.Stride, Imaging.PixelFormat.Format24bppRgb, lock.Scan0)
		if a < 1 then asprite.MakeTransparent asprite.GetPixel(0, 0)
		asprite.RotateFlip(RotateFlipType[flip]) if flip?
		out.DrawImage(asprite,
				new Rectangle(x, y, width, height), 0, 0, asprite.Width, asprite.Height, 
				GraphicsUnit.Pixel, ia)

	grayscale: (level, a = 255) ->
		Color.FromArgb(a, level, level, level)

	saturate: (color, mod = 0.85) ->
		Color.FromArgb(color.R * mod, color.G * mod, color.B * mod)

	render: (s3data, scale = 2) ->
		# Aux procedure.
		make_font = (family, size, style = FontStyle.Regular) =>
			new Font @fonts[family], scale * size, style, System.Drawing.GraphicsUnit.Pixel
		# Init setup.
		return if s3data.team.length is 0
		{player, team}	= s3data
		grid =
			xres:	scale * team[0].sprite.Width
			yres:	scale * team[0].sprite.Height
			caption:scale * 18.5
			header:	scale * 15
			xpages:	2
			ypages: 1
		result		= new Bitmap 1 + grid.xpages*grid.xres*3, grid.header + (grid.yres + grid.caption)*2*grid.ypages
		out			= Graphics.FromImage(result)
		capfont		= make_font "Dosis",	7.5
		traitfont	= make_font "Sylfaen",	6.5
		hdrfont		= make_font "Neue",	8.5
		subhdrfont	= make_font "Neue",	7
		cappen		= new Pen @grayscale(10), 2
		rbrush		= new SolidBrush @grayscale(40, 210)
		cappen.DashStyle		= Drawing2D.DashStyle.Dash
		out.InterpolationMode	= Drawing2D.InterpolationMode.NearestNeighbor
		# BG drawing.
		bgpen			= new Pen Color.DarkGray, 1
		bgpen.DashStyle	= Drawing2D.DashStyle.Dash
		out.DrawImage (bg = new Bitmap("res/auxiliary/bg.jpg")), 0, 0, result.Width/2, result.Height
		@alpha_blt(out, bg, 1 + result.Width/2, 0, result.Width/2, result.Height, 1, 'RotateNoneFlipX')
		out.DrawRectangle bgpen, 0, 0, result.Width-1, result.Height-1
		out.DrawLine bgpen, result.Width/2, -3, result.Width/2, result.Height
		# Header drawing.
		hdrbrush = new SolidBrush(Color.FromArgb 40, @color_code[player.class])
		@draw.block out,0,0,grid.xres,grid.header-3,bgpen,new SolidBrush(Color.FromArgb 40, @color_code[player.class])
		@draw.block out, grid.xres * 2, 0, grid.xres, grid.header - 1.5 * scale, bgpen, hdrbrush 
		@draw.text out, "#{player.name}", hdrfont,	grid.xres * 0.5, -scale/2, Color.Coral
		@draw.text out, "#{player.title}", subhdrfont, grid.xres * 0.5, grid.header * 0.45, Color.Chocolate
		@draw.text out, "#{player.class} Mage", subhdrfont, grid.xres*2.5, -scale/2, @saturate @color_code[player.class]
		@draw.text out, "lvl#{player.level}", hdrfont, grid.xres * 2.5, grid.header*0.375, @color_code[player.class]
		# Runes drawing.
		@draw.text out, player.runes.join('|'), make_font("Sylfaen", 7), grid.xres * 1.5, -2, @grayscale 135
		out.DrawLine new Pen(Color.DarkGray), grid.xres * 1.04, grid.caption * 0.4, grid.xres * 1.96, grid.caption * 0.4
		# Clock and achievments.
		@draw.text out, player.achievs.got+"/"+player.achievs.total, make_font("Neue", 6.5), grid.xres * 1.75, 
			scale * 8, Color.FromArgb(120, 120, 0)
		@draw.text out, player.played,make_font("Neue",6.5),grid.xres*1.25,scale*8,@saturate Color.Coral,0.5
		out.DrawLine new Pen(Color.DarkGray), grid.xres * 1.5, grid.caption * 0.4, grid.xres * 1.5, grid.caption * 0.75
		# Crits drawing.
		for crit, idx in team # Drawing each creaure to canvas.
			[x, y] = [(idx % 3) * grid.xres, grid.header + (idx // 3) * (grid.yres + grid.caption)]
			# Sprite drawing.
			out.SmoothingMode = Drawing2D.SmoothingMode.None
			out.DrawImage crit.sprite, x, y, grid.xres, grid.yres
			out.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias
			@alpha_blt(out, crit.sprite, 1 + x + grid.xres * 3, y, grid.xres, grid.yres, 0.35, 'RotateNoneFlipX')
			if crit.nether
				out.FillEllipse new SolidBrush(Color.FromArgb 110, @color_code[crit.class]), 
					x + 2.75 * scale, y + 3 * scale, 5 * scale, 5.5 * scale
				TR.DrawText out, "★", make_font("Sylfaen", 8, FontStyle.Bold), new Point(x,y), @color_code[crit.class]
			# Name drawing.
			[text, factor] = ["#{crit.name}", 0.93]
			prewidth = @txt.width(text, capfont) * factor
			nfont = if prewidth > 125 then make_font(capfont.FontFamily.Name, 7.5 - 0.08 * (prewidth-125)) else capfont
			cap	= {width: @txt.width(text, nfont) * factor, height: @txt.height(text, capfont)}
			[cap.x,cap.y] = [x + (grid.xres-cap.width) / 2, y + grid.yres]
			text_y = cap.y + (cap.height - @txt.height text, nfont) / 2
			@draw.block out,cap.x,cap.y,cap.width,cap.height,cappen,
				new SolidBrush Color.FromArgb 30, @color_code[crit.class]
			@draw.text out, text, nfont, grid.xres * (idx % 3 + 0.5), text_y, @color_code[crit.class]
			# Additional trait drawing.
			if crit.art.trait
				[yoff, xoff, twidth] = [cap.y+cap.height, grid.xres * (idx % 3 + 0.5)]
				twidth = @txt.width(crit.art.trait, traitfont) * factor
				@draw.block out, x + (grid.xres-twidth) / 2, yoff, twidth, cap.height * 0.7,
					cappen, new SolidBrush @grayscale(40, 200)
				@draw.text out, crit.art.trait, traitfont, xoff, yoff-scale, @grayscale(160)
			# Aux procs for additional data drawing.			
			tablefont = make_font "Neue", 7
			print_down = (text, color = @grayscale(160), font = tablefont, offset = 0) =>
				back = {width: @txt.width(text), height: @txt.height(text)}
				@draw.text out, text, font, 2 + x + grid.xres * 3.5, 1 + y, @saturate color, 0.35
				@draw.text out, text, font, 1 + x + grid.xres * 3.5, y, color
				y += -offset + @txt.height text, font
			delim_line = (color = Color.Gold) =>
				y += scale;	out.DrawLine new Pen(color), x + grid.xres * 3.05, y, x + grid.xres * 3.95, y; y += scale
			# Art and nether data drawing.
			shorten = (txt) ->
				for key, replacer of {
					'Less Damage From': 'Resist'
					'Gained In':		'Per'
					'Increased ':		''
					'Additional':		'Extra'
					'Stat Changes':		'Restat'
					'Penetration':		'Piercing'
				} then return txt.replace(key, replacer) if txt.indexOf(key) > -1
				return txt
			y -= grid.caption / 2
			if crit.art.name
				print_down ":#{crit.art.name}:", Color.Gold, make_font("Neue", 
					(if crit.art.name.length > 19 then 7.5 else 8)), scale
				delim_line()
				delim_line()
				print_down shorten(mod), (if mod[0] is "*" then Color.Orange else Color.Coral) for mod in crit.art.mods
			else print_down "<no artifact>"; delim_line()
			if crit.nethtraits.length
				delim_line()
				print_down "★#{trait}",@color_code[crit.class],make_font("Dosis",7),scale for trait in crit.nethtraits
		return result

	save: (dest) =>		
		System.Windows.Clipboard.SetData System.Windows.Forms.DataFormats.Bitmap, @bmp
		@bmp.Save(dest, Imaging.ImageFormat.Png) if dest
# -------------------
class TermEmu
	colors:
		Black:			0x000000
		DarkBlue:		0x000090
		DarkGreen:		0x009000
		DarkCyan:		0x009090
		DarkRed:		0x900000
		DarkMagenta:	0x900090
		DarkYellow:		0x909000
		Gray:			0xC0C0C0
		DarkGray:		0x808080
		Blue:			0x0000FF
		Green:			0x00FF00
		Cyan:			0x00FFFF
		Red:			0xFF0000
		Magenta:		0xFF00FF
		Yellow:			0xFFFF00
		White:			0xFFFFFF

	# --Methods goes here.
	constructor: () ->
		# Init setup.
		@win										= new System.Windows.Forms.Form()
		@win.Controls.Add(@out						= new System.Windows.Forms.RichTextBox())
		[@win.Width, @win.Height, @win.Icon]		= [790, 700, new Icon('res/auxiliary/siralim.ico')]
		[@out.Width, @out.Height, @out.ReadOnly]	= [@win.Width, @win.Height, true]
		[@out.BackColor, @out.WordWrap, @out.MultiLine]	= [Color.Black, false, true]
		@out.Dock			= System.Windows.Forms.DockStyle.Fill
		@out.BorderStyle	= System.Windows.Forms.BorderStyle.None
		@win.Text			= System.Console.Title
		# Custom font addition.
		collect				= new Text.PrivateFontCollection()
		collect.AddFontFile("res/fonts/TerminalVector.ttf")
		@out.Font			= new Font collect.Families.GetValue(0), 12, FontStyle.Regular, GraphicsUnit.Pixel
		# Finalization.
		@win.StartPosition	= System.Windows.Forms.FormStartPosition.CenterScreen
		@win.Show()

	echo: (txt) ->
		for line, idx in lines = txt.split('\n')
			[@out.SelectionStart, @out.SelectionColor] = [@out.TextLength, @fg]
			@out.AppendText line + (if idx < lines.length-1 then '\n' else '')
		System.Windows.Forms.Application.DoEvents()

	wait_for: (ms) ->
		timer			= new System.Windows.Forms.Timer()
		timer.Interval	= 3000
		timer.Tick.add	(e) -> System.Windows.Forms.Application.Exit()
		timer.Start()
		System.Windows.Forms.Application.Run()

	# --Properties goes here.
	@getter 'fg', (val) -> @fg_
	@setter 'fg', (val)	-> @fg_ = Color.FromArgb switch typeof val
		when 'string' then @colors[val]
		when 'object' then @colors[val.ToString()]
# -------------------
class CUI
	color_code:
		Death:	"darkMagenta"
		Chaos:	"darkRed"
		Nature:	"darkGreen"
		Life:	"gray"
		Sorcery:"darkCyan"

	# --Methods goes here.
	constructor: () ->
		[@fg, @bg] = [ System.Console.ForegroundColor, System.Console.BackgroundColor]
		if System.Console.Title isnt ".[SiraLime]."
			System.Console.Title = ".[SiraLime]."
			@emu = new TermEmu()
		@say header, "green"

	pipe: (s3data) ->
		{team, player} = s3data
		@say '┌', 'white', 
			"#{@plural 'creature', team.length} of #{player.title} #{player.name} (lv#{player.level}|#{player.class
			})/#{player.played}#{player.achievs.progress} parsed:",'cyan'
		for crit in team
			@say("├┬>", 'white', "#{crit.name} (lv#{crit.level}|#{crit.class})", @color_code[crit.class], 
				(if crit.nether then ['[N', crit.aura].join(':')+"]" else ''), 'yellow', 
				(if crit.art.trait then " /" else "") + crit.art.trait, 'darkYellow',
				'\n││', 'white', '┌', @color_code[crit.class], 
				("#{key[0].toUpperCase()}: #{value}" for key,value of crit.stats).join(' '), 'darkGray',
				'\n│' + (if crit.art.name then '╞' else '╘'), 'white', '▒', @color_code[crit.class], ': ', 'white',
				(if crit.gems.length then crit.gems.map((gem) -> gem.name).join ', ' else '<no gems>'), 'darkGray')
			if crit.nethtraits.length
				@say('│' + (if crit.art.name then '│' else ' '), 'white', '╙─', @color_code[crit.class],
					crit.nethtraits.join(' // '), 'yellow')
			if crit.art.name # Printing artifact modifiers now:
				@say '│╘', 'white', '▒', 'darkYellow', ": ", 'white', crit.art.name, 'darkYellow'
				last = ""
				for mod in crit.art.mods
					@say '│ ', 'white', '╟', 'darkYellow', last = mod, 'darkGray'
				@say '│ ', 'white', '╙' + '∙'.repeat(last.length), 'darkYellow'
		@say '└╥──', 'white', "Total deity points = #{player.dpoints}", 'Magenta'
		@say(' ║', 'white', "#{perk.name}: ", 'darkYellow'
			"#{perk.lvl} / #{perk.max}", 'darkGray') for perk in player.perks
		@say ' ╟─', 'white', (if player.runes then player.runes.join('/') else "No") +
			"#{@plural 'rune', player.runes.length, false} equipped.", 'yellow'
		@say " ╙──►Game version: #{player.version}", 'white'
		return s3data

	show_off: (img) ->
		if img then @say("\nWork complete: image successfully pasted to clipboard !", 'green')
		else @say("\nWork aborted: no creatures to render was found.", 'red')
		return img

	plural: (word, num, concat = true) ->
		"#{if concat then num else ''} #{word}#{if num is 1 then '' else 's'}"

	out: (txt = '\n') ->
		process.stdout.write txt
		@emu?.echo txt
	
	say: (txt, color) ->
		arg = 0
		arguments[arguments.length - 2 + arguments.length % 2] += '\n'
		while arg < arguments.length
			@out ([txt, @color] = [arguments[arg++], SiralimData.capitalize arguments[arg++] ? ""])[0]

	fail: (ex) ->
		@say "FAIL:: #{ex.stack.split('\n')[0..-16].join('\n')}", 'red'

	done: (lapse = 3000) ->
		[System.Console.ForegroundColor, System.Console.BackgroundColor] = [@fg, @bg]
		if @emu? then @emu.wait_for(lapse) else System.Threading.Thread.Sleep(lapse)

	# --Properties goes here.
	@setter 'color', (val) -> if val then System.Console.ForegroundColor = System.ConsoleColor[val]; @emu?.fg = val
#.}

# --Main code--
System.IO.Directory.SetCurrentDirectory "#{__dirname}\\.."
ui = new CUI
try	
	feed = try new SiralimData System.Windows.Clipboard.GetText() catch then new SiralimData
	new Render(feed, ui.pipe.bind(ui), ui.show_off.bind(ui))
catch ex then ui.fail(ex)
ui.done()