header = """
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
	# SiraLime teamcards renderer v0.4
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
		txt[0].toUpperCase() + txt[1..]#.toLowerCase()

	get_field: (feed, field) ->
		feed.find((elem) -> elem.startsWith field + ": ")?.split(field + ": ")[1]

	get_list: (feed, matcher) ->
		feed.filter((x) -> matcher.test x).map((x) -> x.match(matcher)[1])

	player_data: (fragment) ->
		headline	= fragment[0].match(/([\w\s]+) (.*), Level (\d*) (\w*) Mage/)
		perkfinder	= /(.*) \(Rank (\d*)(?: \/ )(\d*)?\)/
		achievments	= @get_field(fragment, "Achievement Points").split(' ')
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
		[stats, naming, spec] = [{}, fragment[0].split(' '), fragment[1].match /(.*) \/ (.*)/]
		Object.assign stats, {[stat]: BigInt @get_field(fragment, SiralimData.capitalize stat)} for stat in [
			'health', 'mana', 'attack', 'intelligence', 'defense', 'speed']
		art_idx = fragment.findIndex (x) -> x.startsWith "Artifact: "


		singular:	if naming[naming.length-1] == '(Singular)'	then naming.pop(); true else false
		nether:		if naming[naming.length-1] == '(Nether)'	then naming.pop(); true else false
		name:		name = naming[2..].join(' ')
		level:		BigInt naming[1]
		kind:		spec[1]
		class:		spec[2]
		sprite:		@load_sprite(name)
		aura:		@get_field(fragment, "Nether Aura: Nether Aura") ? ""
		arttrait:	@get_field(fragment, "Trait") ? ""
		nethtraits:	@get_list(fragment, /Nether Trait: (.*)/)
		gems:		@get_list(fragment, /Gem of (.*) \(Mana/)
		stats:		stats

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
class Lineup
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
			if crit.arttrait
				[yoff, xoff, twidth] = [cap.y+cap.height, grid.xres * (idx % 3 + 0.5)]
				twidth = TR.MeasureText(crit.arttrait, traitfont).Width * 0.96
				@draw_block out, x + (grid.xres-twidth) / 2, yoff, twidth, cap.height * 0.7,
					cappen, new SolidBrush @grayscale(40, 200)
				@print_centered out, crit.arttrait, traitfont, xoff, yoff-scale, @grayscale(160)
		return result

	save: (dest) =>		
		System.Windows.Clipboard.SetData System.Windows.Forms.DataFormats.Bitmap, @bmp
		@bmp.Save(dest, Imaging.ImageFormat.Png) if dest
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
		@say header, "green"

	pipe: (s3data) ->
		{team, player} = s3data
		@say '┌', 'white', 
			"#{@plural 'creature', team.length} of #{player.title} #{player.name}(lv#{player.level}|#{player.class
			})/#{player.played}#{player.achievs.progress} parsed:",'cyan'
		@say("├┬>", 'white', "#{crit.name} (lv#{crit.level}|#{crit.class})", @color_code[crit.class], 
			(if crit.nether then ['[N', crit.aura].join(':')+"]" else ''), 'yellow', 
			(if crit.arttrait then " /" else "") + crit.arttrait, 'darkYellow',
			'\n││', 'white', '┌', @color_code[crit.class], 
			("#{key[0].toUpperCase()}: #{value}" for key,value of crit.stats).join(' '), 'darkGray',
			'\n│╘', 'white', '▒', @color_code[crit.class], ': ', 'white',
			(if crit.gems.length then crit.gems.join ', ' else '<no gems>'), 'darkGray'
			(if crit.nethtraits.length then '\n│ ' else ""), 'white',
			(if crit.nethtraits.length then '╙─' else ""), @color_code[crit.class],
			crit.nethtraits.join(' // '), 'yellow',
			) for crit in team
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
		"#{if concat then num else ''} #{word}#{if num == 1 then '' else 's'}"
	
	say: (txt, color) ->
		arg = 0
		while arg < arguments.length
			[txt, color] = [arguments[arg++], arguments[arg++]]
			if color? then System.Console.ForegroundColor = System.ConsoleColor[SiralimData.capitalize color]
			process.stdout.write txt
		console.log ""

	fail: (ex) ->
		@say "FAIL:: #{ex}", 'red'

	done: () ->
		[System.Console.ForegroundColor, System.Console.BackgroundColor] = [@fg, @bg]
		System.Threading.Thread.Sleep(3000)
#.}

# --Main code--
System.IO.Directory.SetCurrentDirectory "#{__dirname}\\.."
try 
	ui = new CUI
	feed = try new SiralimData System.Windows.Clipboard.GetText() catch then new SiralimData
	new Lineup(feed, ui.pipe.bind(ui), ui.show_off.bind(ui))
catch ex then ui.fail(ex)
ui.done()