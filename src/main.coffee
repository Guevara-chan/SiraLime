header = """
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
	# SiraLime teamcards renderer v0.1
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

	crit_data: (fragment) ->
		[naming, typing] = fragment.map (x) -> x.split ' '
		nether: if naming[naming.length-1] == '(Nether)' then naming.pop(); nether = true else false
		name:	name = naming[2..].join(' ')
		level:	naming[1]
		kind:	typing[0..typing.length-3].join ' '
		class:	typing[typing.length-1]
		sprite:	@load_sprite(name)

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
		Nature:	Color.Chartreuse #FromArgb(255, 31, 78, 47)
		Life:	Color.GhostWhite
		Sorcery:Color.Cyan

	# --Methods goes here.
	constructor: (src, pipe, show_off, dest) ->
		@bmp = show_off @render pipe new SiralimData src
		if dest? then Lineup.save(@bmp, dest)
		System.Windows.Clipboard.SetData System.Windows.Forms.DataFormats.Bitmap, @bmp

	render: (s3data, scale = 2) =>
		# Init setup.
		{team}	= s3data
		grid	= {xres: team[0].sprite.Width * scale, yres: team[0].sprite.Height * scale, caption: 25}
		result	= new Bitmap grid.xres * 3, (grid.yres + grid.caption) * 2
		out		= Graphics.FromImage(result)
		capfont	= new Font("Sylfaen", 5.5 * scale)
		cappen	= new Pen(System.Drawing.Color.FromArgb(10, 10, 10), 2)
		rbrush	= new SolidBrush(System.Drawing.Color.FromArgb(210, 40, 40, 40))
		cappen.DashStyle		= Drawing2D.DashStyle.Dash
		out.InterpolationMode	= System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor
		# BG drawing.
		bgpen = new Pen(System.Drawing.Color.DarkGray, 1)
		bgpen.DashStyle	= Drawing2D.DashStyle.Dash
		out.DrawImage new Bitmap("res\\bg.jpg"), 0, 0, result.Width, result.Height
		out.DrawRectangle bgpen, 0, 0, result.Width-1, result.Height-1
		# Actual drawing.
		for crit, idx in team # Drawing each creaure to canvas.
			[x, y] = [(idx % 3) * grid.xres, (idx // 3) * (grid.yres + grid.caption)]
			# Sprite drawing.
			out.SmoothingMode = Drawing2D.SmoothingMode.None
			out.DrawImage crit.sprite, x, y, grid.xres, grid.yres
			out.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias
			# Caption drawing.
			text = "#{crit.name}"#" lvl#{crit.level}"
			cap	= {width: out.MeasureString(text, capfont).Width, height: out.MeasureString(text, capfont).Height}
			[cap.x,cap.y] = [x + (grid.xres-cap.width) / 2, y + grid.yres]
			out.FillRectangle(rbrush, cap.x, cap.y, cap.width, cap.height)
			out.DrawRectangle(cappen, cap.x, cap.y, cap.width, cap.height)
			System.Windows.Forms.TextRenderer.DrawText(out,text,capfont,new Point(cap.x,cap.y), @color_code[crit.class])
		return result

	@save: (lineup, dest = "Team.png") =>
		lineup.Save(dest, Imaging.ImageFormat.Png)
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
		System.Console.Title = ".[SiraLime]."
		@say header, "green"

	pipe: (s3data) ->
		{team, player} = s3data
		@say "┌", 'white', 
			"#{team.length} creatures for #{player.gender} #{player.name} 
			(lv#{player.level}|#{player.class}) parsed:", 'cyan'
		@say("├>", 'white', "#{crit.name} (lv#{crit.level}|#{crit.class})", @color_code[crit.class]) for crit in team
		@say "└", 'white', "Generating teamcard...", 'yellow'
		return s3data

	show_off: (img) ->
		@say("\nWork complete: image succesfully pasted to clipboard !", 'green')
		return img

	done: () ->
		System.Threading.Thread.Sleep(3000)

	capitalize: (txt) ->
		txt[0].toUpperCase() + txt[1..]#.toLowerCase()
	
	say: (txt, color) ->
		arg = 0
		while arg < arguments.length
			[txt, color] = [arguments[arg++], arguments[arg++]]
			if color? then System.Console.ForegroundColor = System.ConsoleColor[@capitalize color]
			process.stdout.write txt
		console.log ""

	fail: (ex) ->
		@say "FAIL:: #{ex}", 'red'
#.}

# --Main code--
ui = new CUI
try
	System.IO.Directory.SetCurrentDirectory "#{__dirname}\\.."
	feed = undefined unless try new SiralimData feed=System.Windows.Clipboard.GetText()
	new Lineup(feed, ui.pipe.bind(ui), ui.show_off.bind(ui), "last.png")
catch ex
	ui.fail(ex)
ui.done()