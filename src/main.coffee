header = """
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
	# SiraLime teamcards renderer v0.1
	# Developed in 2019 by Guevara-chan
	# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

"""
clr = require('clr').init assemblies: ['System','mscorlib','System.Drawing','System.Windows.Forms','PresentationCore']
Object.assign global, namespace for namespace in [System.Drawing]

#.{ [Classes]
# -------------------	
class Lineup
	_cache = "cache.txt"

	# --Methods goes here.
	constructor: (src, pipe, show_off, dest) ->
		@bmp = show_off Lineup.render pipe Lineup.parse_export src
		if dest? then Lineup.save(@bmp, dest)
		System.Windows.Clipboard.SetData System.Windows.Forms.DataFormats.Bitmap, @bmp

	@load_sprite: (crit_name) =>
		try return new Bitmap("res\\#{name}.png")
		client = new System.Net.WebClient()
		stream = client.
			OpenRead "https://raw.githubusercontent.com/Guevara-chan/SiraLime/master/res/#{encodeURI crit_name}.png"
		return new Bitmap(stream)

	@parse_export: (src = System.IO.File.ReadAllText _cache) =>
		# Aux procedures.
		crit_data = (chunks) =>
			if chunks[chunks.length-1] == '(Nether)' then chunks.pop()
			level:	chunks[1]
			name:	name = chunks[2..].join(' ')
			sprite:	Lineup.load_sprite(name)#
		# Main parser.
		feed = src.split('\r\n')
		if feed[0] is '========== CHARACTER ==========' # If header is valid...
			System.IO.File.WriteAllText _cache, src, System.Text.Encoding.ASCII
			(crit_data(line.split(' ')) for line in feed when line.startsWith 'Level ')
		else throw new Error "Invalid export data provided."

	@render: (creatures, scale = 2) =>
		# Init setup.
		grid	= {xres: creatures[0].sprite.Width * scale, yres: creatures[0].sprite.Height * scale, caption: 25}
		result	= new Bitmap grid.xres * 3, (grid.yres + grid.caption) * 2
		out		= Graphics.FromImage(result)
		capfont	= new Font("Sylfaen", 5.5 * scale)
		cappen	= new Pen(System.Drawing.Color.FromArgb(255, 10, 10, 10), 2)
		rbrush	= new SolidBrush(System.Drawing.Color.FromArgb(210, 40, 40, 40))
		cappen.DashStyle		= Drawing2D.DashStyle.Dash
		out.InterpolationMode	= System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor
		# BG drawing.
		bgpen = new Pen(System.Drawing.Color.DarkGray, 1)
		bgpen.DashStyle	= Drawing2D.DashStyle.Dash
		out.DrawImage new Bitmap("res\\bg.jpg"), 0, 0, result.Width, result.Height
		out.DrawRectangle bgpen, 0, 0, result.Width-1, result.Height-1
		# Actual drawing.
		for crit, idx in creatures # Drawing each creaure to canvas.
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
			System.Windows.Forms.TextRenderer.DrawText(out,text,capfont,new Point(cap.x,cap.y), Color.GhostWhite)
		return result

	@save: (lineup, dest = "Team.png") =>
		lineup.Save(dest, Imaging.ImageFormat.Png)
# -------------------
class CUI
	# --Methods goes here.
	constructor: () ->
		System.Console.Title = ".[SiraLime]."
		@say header, "green"

	pipe: (creatures) ->
		@say "┌", 'white', "#{creatures.length} creatures parsed:", 'cyan'
		@say("├>", 'white', "#{crit.name}", 'darkGray') for crit in creatures
		@say "└", 'white', "Generating teamcard...", 'yellow'
		return creatures

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
	feed = undefined unless try Lineup.parse_export feed=System.Windows.Clipboard.GetText()
	new Lineup(feed, ui.pipe.bind(ui), ui.show_off.bind(ui), "last.png")
catch ex
	ui.fail(ex)
ui.done()