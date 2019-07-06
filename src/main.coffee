header = """
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
	# SiraLime teamcards renderer v0.2
	# Developed in 2019 by Guevara-chan
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

"""
clr = require('clr').init assemblies: ['System','mscorlib','System.Drawing','System.Windows.Forms','PresentationCore']
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

	player_data: (fragment) ->
		[naming, spec] = fragment[0].split(', ').map (x) -> x.split ' '
		gender: naming[0]
		name:	naming[1]
		level:	spec[1]
		class:	spec[2]
		runes:	fragment.filter((x) -> x.split(' ')[1] == 'Rune:').map((x) -> x.split(' ')[0]) ? []

	crit_data: (fragment) ->
		[naming, typing] = fragment.map (x) -> x.split ' '
		nether:		if naming[naming.length-1] == '(Nether)' then naming.pop(); nether = true else false
		name:		name = naming[2..].join(' ')
		level:		naming[1]
		kind:		typing[0..typing.length-3].join ' '
		class:		typing[typing.length-1]
		sprite:		@load_sprite(name)
		arttrait:	(fragment.find((x) -> x.startsWith 'Trait: ')?.split(' ')[1..].join(' ')) ? ""

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
		TR.DrawText out, txt, font, new Point(x - (TR.MeasureText(txt, font).Width / 2), y), color

	draw_block: (out, x, y, width, height, pen, brush) ->
		out.FillRectangle brush, x, y, width, height
		out.DrawRectangle pen, x, y, width, height

	set_alpha: (color, a = 40) ->
		Color.FromArgb(a, color.R, color.G, color.B)

	render: (s3data, scale = 2) =>
		# Init setup.
		{player, team}	= s3data
		grid =
			xres:	scale * team[0].sprite.Width
			yres:	scale * team[0].sprite.Height
			caption:scale * 18.5
			header:	scale * 12.5
		result		= new Bitmap grid.xres * 3, grid.header + (grid.yres + grid.caption) * 2
		out			= Graphics.FromImage(result)
		capfont		= new Font("Sylfaen", scale * 5.5)
		traitfont	= new Font("Sylfaen", scale * 4.5)
		hdrfont		= new Font("Sylfaen", scale * 6, FontStyle.Bold)
		cappen		= new Pen(Color.FromArgb(10, 10, 10), 2)
		rbrush		= new SolidBrush(Color.FromArgb(210, 40, 40, 40))
		cappen.DashStyle		= Drawing2D.DashStyle.Dash
		out.InterpolationMode	= Drawing2D.InterpolationMode.NearestNeighbor
		# BG drawing.
		bgpen			= new Pen(Color.DarkGray, 1)
		bgpen.DashStyle	= Drawing2D.DashStyle.Dash
		out.DrawImage new Bitmap("res\\bg.jpg"), 0, 0, result.Width, result.Height
		out.DrawRectangle bgpen, 0, 0, result.Width-1, result.Height-1
		# Header drawing.
		hdrbrush = new SolidBrush(@set_alpha @color_code[player.class])
		@draw_block out, 0, 0, grid.xres, grid.header-3, bgpen, new SolidBrush(@set_alpha @color_code[player.class])
		@draw_block out, result.Width - grid.xres, 0, grid.xres, grid.header-3, bgpen, hdrbrush 
		@print_centered out, "#{player.gender} #{player.name}", hdrfont, grid.xres * 0.5, 0, Color.Coral
		@print_centered out, "lvl#{player.level}|#{player.class}", hdrfont, grid.xres * 2.5, 0,@color_code[player.class]
		# Runes drawing.
		@print_centered out, player.runes.join('|'), new Font("Sylfaen", scale * 5), grid.xres * 1.5, -2, Color.Gray
		out.DrawLine new Pen(Color.DarkGray), grid.xres * 1.04, grid.caption * 0.4, grid.xres * 1.96, grid.caption * 0.4
		# Crits drawing.
		for crit, idx in team # Drawing each creaure to canvas.
			[x, y] = [(idx % 3) * grid.xres, grid.header + (idx // 3) * (grid.yres + grid.caption)]
			# Sprite drawing.
			out.SmoothingMode = Drawing2D.SmoothingMode.None
			out.DrawImage crit.sprite, x, y, grid.xres, grid.yres
			out.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias
			if crit.nether then TR.DrawText out, "★", hdrfont, new Point(x, y), @color_code[crit.class]
			# Name drawing.
			text = "#{crit.name}"#" lvl#{crit.level}"
			cap	= {width: (TR.MeasureText(text, capfont)).Width, height: (TR.MeasureText(text, capfont)).Height}
			[cap.x,cap.y] = [x + (grid.xres-cap.width) / 2, y + grid.yres]
			@draw_block out,cap.x,cap.y,cap.width,cap.height,cappen,new SolidBrush @set_alpha @color_code[crit.class],30
			@print_centered out, text, capfont, grid.xres * (idx % 3 + 0.5) , cap.y, @color_code[crit.class]
			# Additional trait drawing.
			if crit.arttrait
				[yoff, xoff, twidth] = [cap.y+cap.height, grid.xres * (idx % 3 + 0.5)]
				twidth = TR.MeasureText(crit.arttrait, traitfont).Width * 0.96
				@draw_block out, x + (grid.xres-twidth) / 2, yoff, twidth, cap.height * 0.7,
					cappen, new SolidBrush Color.FromArgb(200, 40, 40, 40)
				@print_centered out, crit.arttrait, traitfont, xoff, yoff, Color.FromArgb(255, 160, 160, 160)			
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
		@say "┌", 'white', 
			"#{@plural 'creature', team.length} of #{player.gender} #{player.name} 
			(lv#{player.level}|#{player.class}) parsed:", 'cyan'
		@say("├>", 'white', "#{crit.name} (lv#{crit.level}|#{crit.class})", @color_code[crit.class], 
			(if crit.nether then '[N]' else ''), 'white', 
				(if crit.arttrait then " /" else "") + crit.arttrait, 'darkGray') for crit in team
		@say "└", 'white', (if player.runes then player.runes.join('/') else "No") +
			"#{@plural 'rune', player.runes.length, false} equipped.", 'yellow'
		return s3data

	show_off: (img) ->
		@say("\nWork complete: image successfully pasted to clipboard !", 'green')
		return img

	capitalize: (txt) ->
		txt[0].toUpperCase() + txt[1..]#.toLowerCase()

	plural: (word, num, concat = true) ->
		"#{if concat then num else ''} #{word}#{if num == 1 then '' else 's'}"
	
	say: (txt, color) ->
		arg = 0
		while arg < arguments.length
			[txt, color] = [arguments[arg++], arguments[arg++]]
			if color? then System.Console.ForegroundColor = System.ConsoleColor[@capitalize color]
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
	feed = try new SiralimData System.Windows.Clipboard.GetText() catch
		new SiralimData
	new Lineup(feed, ui.pipe.bind(ui), ui.show_off.bind(ui))
catch ex
	ui.fail(ex)
ui.done()