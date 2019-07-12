header = """
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
	# SiraLime teamcards renderer v0.5
	# Developed in 2019 by Guevara-chan
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

"""
clr = require('clr').init assemblies: 'System|mscorlib|System.Drawing|System.Windows.Forms|PresentationCore'.split '|'
Object.assign global, namespace for namespace in [System.Drawing]

#.{ [Classes]
class SiralimData
	source_cache = "cache.txt"

	# --Methods goes here.
	constructor:  (src = System.IO.File.ReadAllText source_cache) ->
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

	get_field: (feed, field) ->
		matcher = new RegExp field + ": (.*)"
		idx = feed?.findIndex((elem) -> matcher.test elem)
		feed.splice(idx, 1)[0].match(matcher)[-1..][0] if idx != -1		

	get_list: (feed, matcher) ->
		feed.filter((x) -> matcher.test x).map((x) -> x.match(matcher)[1])

	player_data: (fragment) ->
		# Init setup.
		headline	= fragment[0].match(/([\w\s]+) (.*), Level (\d*) (\w*) Mage/)
		perkfinder	= /(.*) \(Rank (\d*)(?: \/ )(\d*)?\)/
		achievments	= @get_field(fragment, "Achievement Points").split(' ')
		# Actual extraction.
		title:		headline[1]
		name:		headline[2]
		level:		BigInt headline[3]
		class:		headline[4]
		played:		@get_field(fragment, "Time Played")
		version:	@get_field(fragment, "Game Version")
		dpoints:	BigInt @get_field(fragment, "Total Deity Points")
		runes:		@get_list(fragment, /(\w*) Rune:/)
		achievs:	{got: parseInt(achievments[0]), total: parseInt(achievments[2]), progress: achievments[3]}
		perks:		fragment.filter((x) -> perkfinder.test x).map (x) ->
			{name: (arr = perkfinder.exec(x)[1..3])[0], lvl: BigInt(arr[1]), max: arr[2]}

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
		aura:		@get_field(fragment, "Nether Aura: Nether Aura") ? ""
		nethtraits:	@get_list(fragment, /Nether Trait: (.*)/)
		gems:		@get_list(fragment, /Gem of (.*) \(Mana/)
		stats:		(Object.assign stats,
			{[stat]: BigInt @get_field fragment, SiralimData.capitalize(stat) + '( \\(.*\\))?'} for stat in [
				'health', 'mana', 'attack', 'intelligence', 'defense', 'speed'])[0]
		art:
			name:	@get_field(art_data, "Artifact") ? ""
			trait:	@get_field(art_data, "Trait") ? ""
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
		@bmp = show_off @render pipe s3data
		@save(dest)

	print_centered: (out, txt, font, x, y, color) ->
		TR.DrawText out, txt, font, new Point(x - (TR.MeasureText(txt, font).Width / 2)+1, y), color

	draw_block: (out, x, y, width, height, pen, brush) ->
		out.FillRectangle brush, x, y, width, height
		out.DrawRectangle pen, x, y, width, height

	set_alpha: (color, a = 40) ->
		Color.FromArgb(a, color.R, color.G, color.B)

	grayscale: (level, a = 255) ->
		Color.FromArgb(a, level, level, level)

	saturate: (color, mod = 0.85) ->
		Color.FromArgb(color.R * mod, color.G * mod, color.B * mod)

	render: (s3data, scale = 2) ->
		# Aux procedure.
		make_font = (family, size, style = FontStyle.Regular) =>
			#console.log size
			new Font family, scale * size, style, System.Drawing.GraphicsUnit.Pixel
		# Init setup.
		{player, team}	= s3data
		grid =
			xres:	scale * team[0].sprite.Width
			yres:	scale * team[0].sprite.Height
			caption:scale * 18.5
			header:	scale * 15
		result		= new Bitmap grid.xres * 3, grid.header + (grid.yres + grid.caption) * 2
		out			= Graphics.FromImage(result)
		capfont		= make_font "Sylfaen", 7.5
		traitfont	= make_font "Sylfaen", 6.5
		hdrfont		= make_font "Impact", 7.5
		subhdrfont	= make_font "Impact", 6
		cappen		= new Pen @grayscale(10), 2
		rbrush		= new SolidBrush @grayscale(40, 210)
		cappen.DashStyle		= Drawing2D.DashStyle.Dash
		out.InterpolationMode	= Drawing2D.InterpolationMode.NearestNeighbor
		# BG drawing.
		bgpen			= new Pen Color.DarkGray, 1
		bgpen.DashStyle	= Drawing2D.DashStyle.Dash
		out.DrawImage new Bitmap("res\\bg.jpg"), 0, 0, result.Width, result.Height
		out.DrawRectangle bgpen, 0, 0, result.Width-1, result.Height-1
		# Header drawing.
		hdrbrush = new SolidBrush(@set_alpha @color_code[player.class])
		@draw_block out, 0, 0, grid.xres, grid.header-3, bgpen, new SolidBrush(@set_alpha @color_code[player.class])
		@draw_block out, result.Width - grid.xres, 0, grid.xres, grid.header - 1.5 * scale, bgpen, hdrbrush 
		@print_centered out, "#{player.name}", hdrfont,	grid.xres * 0.5, -scale, Color.Coral
		@print_centered out, "#{player.title}", subhdrfont, grid.xres * 0.5, grid.header * 0.4, Color.Chocolate
		@print_centered out, "#{player.class} Mage", subhdrfont, grid.xres * 2.5, -scale, 
			@saturate @color_code[player.class]
		@print_centered out, "lvl#{player.level}", hdrfont, grid.xres * 2.5, grid.header*0.32, @color_code[player.class]
		# Runes drawing.
		@print_centered out, player.runes.join('|'), make_font("Sylfaen", 7), grid.xres * 1.5, -2, @grayscale 135
		@print_centered out, player.played,make_font("Impact",5.5),grid.xres*1.25,scale*7.5,@saturate Color.Coral,0.5
		out.DrawLine new Pen(Color.DarkGray), grid.xres * 1.04, grid.caption * 0.4, grid.xres * 1.96, grid.caption * 0.4
		# Clock and achievments.
		@print_centered out, player.achievs.got+"/"+player.achievs.total, make_font("Impact", 5.5), grid.xres * 1.75, 
			scale * 7.5, Color.FromArgb(120, 120, 0)
		out.DrawLine new Pen(Color.DarkGray), grid.xres * 1.5, grid.caption * 0.4, grid.xres * 1.5, grid.caption * 0.75
		# Crits drawing.
		for crit, idx in team # Drawing each creaure to canvas.
			[x, y] = [(idx % 3) * grid.xres, grid.header + (idx // 3) * (grid.yres + grid.caption)]
			# Sprite drawing.
			out.SmoothingMode = Drawing2D.SmoothingMode.None
			out.DrawImage crit.sprite, x, y, grid.xres, grid.yres
			out.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias
			if crit.nether
				out.FillEllipse new SolidBrush(@set_alpha @color_code[crit.class], 110), 
					x + 2.75 * scale, y + 3 * scale, 5 * scale, 5.5 * scale
				TR.DrawText out, "★", make_font("Sylfaen",8,FontStyle.Bold),new Point(x,y),@color_code[crit.class]
			# Name drawing.
			text = "#{crit.name}"#" lvl#{crit.level}"
			cap	= {width: (TR.MeasureText(text, capfont)).Width*0.93, height: (TR.MeasureText(text, capfont)).Height}
			[cap.x,cap.y] = [x + (grid.xres-cap.width) / 2, y + grid.yres]
			@draw_block out,cap.x,cap.y,cap.width,cap.height,cappen,new SolidBrush @set_alpha @color_code[crit.class],30
			@print_centered out, text, capfont, grid.xres * (idx % 3 + 0.5), cap.y, @color_code[crit.class]
			# Additional trait drawing.
			if crit.art.trait
				[yoff, xoff, twidth] = [cap.y+cap.height, grid.xres * (idx % 3 + 0.5)]
				twidth = TR.MeasureText(crit.art.trait, traitfont).Width * 0.96
				@draw_block out, x + (grid.xres-twidth) / 2, yoff, twidth, cap.height * 0.7,
					cappen, new SolidBrush @grayscale(40, 200)
				@print_centered out, crit.art.trait, traitfont, xoff, yoff-scale, @grayscale(160)
		return result

	save: (dest) =>		
		System.Windows.Clipboard.SetData System.Windows.Forms.DataFormats.Bitmap, @bmp
		@bmp.Save(dest, Imaging.ImageFormat.Png) if dest
# -------------------
class TermEmu
	colors: [0x000000, #Black = 0
				0x000090, #DarkBlue = 1
				0x009000, #DarkGreen = 2
				0x009090, #DarkCyan = 3
				0x900000, #DarkRed = 4
				0x900090, #DarkMagenta = 5
				0x909000, #DarkYellow = 6
				0xC0C0C0, #Gray = 7
				0x808080, #DarkGray = 8
				0x0000FF, #Blue = 9
				0x00FF00, #Green = 10
				0x00FFFF, #Cyan = 11
				0xFF0000, #Red = 12
				0xFF00FF, #Magenta = 13
				0xFFFF00, #Yellow = 14
				0xFFFFFF  #White = 15
			]

	# --Methods goes here.
	constructor: () ->
		# Init setup.
		@win = new System.Windows.Forms.Form()
		@win.Controls.Add(@out = new System.Windows.Forms.RichTextBox())
		[@win.Width, @win.Height, @win.Icon]		= [700, 700, new Icon('res\\siralim.ico')]
		[@out.Width, @out.Height, @out.ReadOnly]	= [@win.Width, @win.Height, true]
		@out.Dock			= System.Windows.Forms.DockStyle.Fill
		@out.BorderStyle	= System.Windows.Forms.BorderStyle.None
		@out.BackColor		= Color.Black
		@win.Text			= System.Console.Title
		# Custom font addition.
		collect				= new Text.PrivateFontCollection()
		collect.AddFontFile("res\\TerminalVector.ttf")
		@out.Font			= new Font collect.Families.GetValue(0), 12, FontStyle.Regular,
			GraphicsUnit.Pixel
		# Finalization.
		@win.StartPosition	= System.Windows.Forms.FormStartPosition.CenterScreen
		@win.Show()

	echo: (txt) ->
		for line, idx in lines = txt.split('\n')
			@out.SelectionStart = @out.TextLength
			@out.SelectionColor = @fg
			@out.AppendText line + (if idx < lines.length-1 then '\n' else '')
		System.Windows.Forms.Application.DoEvents()
		
	set_fg: (color) ->
		@fg = Color.FromArgb @colors[System.Convert.ChangeType(System.ConsoleColor[color], System.Int32)]

	wait_for: (ms) ->
		timer			= new System.Windows.Forms.Timer()
		timer.Interval	= 3000
		timer.Tick.add	(e) -> System.Windows.Forms.Application.Exit()
		timer.Start()
		System.Windows.Forms.Application.Run()
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
		[@fg, @bg] = [ System.Console.ForegroundColor,  System.Console.BackgroundColor]
		System.Console.Title = ".[SiraLime]."
		System.Console.ForegroundColor
		@emu = new ConEmu()
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
			(if crit.gems.length then crit.gems.join ', ' else '<no gems>'), 'darkGray'
			(if crit.nethtraits.length then '\n│' + (if crit.art.name then '│' else ' ') else ""), 'white',
			(if crit.nethtraits.length then '╙─' else ""), @color_code[crit.class],
			crit.nethtraits.join(' // '), 'yellow')
			if crit.art.mods isnt [] # Printing artifact modifiers now:
				@say '│╘', 'white', '▒', 'darkYellow', ": ", 'white', crit.art.name, 'darkYellow'
				last = ""
				for mod in crit.art.mods
					@say '│ ', 'white', '╟', 'darkYellow', last = mod, 'darkGray'
				@say '│ ', 'white', '╙' + '∙'.repeat(last.length), 'darkYellow'
		@say '└╥──', 'white', "Total deity points = #{player.dpoints}", 'Magenta'
		@say(' ║', 'white', "#{perk.name}: ", 'darkYellow'
			"#{perk.lvl} #{if perk.max then '/ ' + perk.max else ''}", 'darkGray') for perk in player.perks
		@say ' ╟─', 'white', (if player.runes then player.runes.join('/') else "No") +
			"#{@plural 'rune', player.runes.length, false} equipped.", 'yellow'
		@say " ╙──►Game version: #{player.version}", 'white'
		return s3data

	show_off: (img) ->
		@say("\nWork complete: image successfully pasted to clipboard !", 'green')
		return img

	plural: (word, num, concat = true) ->
		"#{if concat then num else ''} #{word}#{if num is 1 then '' else 's'}"

	out: (txt = '\n') ->
		process.stdout.write txt
		@emu?.echo txt
	
	say: (txt, color) ->
		arg = 0
		while arg < arguments.length
			[txt, color] = [arguments[arg++], arguments[arg++]]
			if color?# then
				System.Console.ForegroundColor = System.ConsoleColor[SiralimData.capitalize color]
				@emu?.set_fg SiralimData.capitalize color
			@out txt
		@out()

	fail: (ex) ->
		@say "FAIL:: #{ex}", 'red'

	done: (lapse = 3000) ->
		[System.Console.ForegroundColor, System.Console.BackgroundColor] = [@fg, @bg]
		if @emu? then @emu.wait_for(lapse) else System.Threading.Thread.Sleep(lapse)
#.}

# --Main code--
System.Windows.Forms.Application.SetCompatibleTextRenderingDefault(false)
System.IO.Directory.SetCurrentDirectory "#{__dirname}\\.."
try 
	ui = new CUI
	feed = try new SiralimData System.Windows.Clipboard.GetText() catch then new SiralimData
	new Render(feed, ui.pipe.bind(ui), ui.show_off.bind(ui))
catch ex then ui.fail(ex)
ui.done()