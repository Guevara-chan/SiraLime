# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Uni|Grab unified data ripper core
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import os, strutils, htmlparser, xmlparser, parsecsv, xmltree, uri, httpclient, threadpool, asyncdispatch
import sequtils, parseutils, strtabs

#.{ [Classes]
when not defined(UniData):
    type UniData* = object
        ip, port, creds: string

    # --Methods goes here:
    proc raw*(self: UniData, add_port = true, add_creds = true, http_style = true): string {.inline} =
        let parts = [self.ip & (if add_port: ":" & self.port else: ""), (if add_creds: self.creds else: "")]
        return parts[http_style.int] & (if parts[1].len>1: $" @"[http_style.int] else: "") & parts[http_style.not.int]

    proc check*(self: UniData, timeout = 5000): Future[string] {.async.} =
        # Aux proc.
        proc checkNil(txt: string): string =
            result = txt.replace('\n', ' ').strip(); if result == "": raise newException(ValueError, "I Am Error")
        proc anyText(root: XmlNode): string =
            for child in root: (try: return child.innerText.checkNil except: discard)
        # Init setup.
        let url = "http://" & self.raw()
        let client = newAsyncHttpClient()
        let future = client.getContent(url)
        yield future.withTimeout(timeout)
        client.close()
        # Actual handling.
        let resp = FutureVar[string](future).mget()
        if future.failed or resp.len == 0: return ""
        else:
            let brief = if resp.len > 15:     # Any reasons to ever parse?
                try:
                    let html = resp.parseHtml # OK, breaking it to either title tag or text of any child:
                    try: html.findAll("title")[0].innerText.checkNil except: html.anyText.checkNil.substr(0, 20)
                except: ":/nil/:"             # No luck == nil
            else: resp                        # No reason == returning as is.
            return url & " == " & brief

    proc compose*(ip: string, port: int|string, creds: string = ""): UniData {.inline} =
        result = UniData(ip: ip, port: $port, creds: creds)
# -----------------------
when not defined(LexTrio):
    type LexTrio = tuple[ip: int, port: int, creds: int]
    type LexMap  = tuple[ip: string, port: string, creds: string]

    # --Methods goese here.
    proc isIP(src: string): bool =
        result = try: 
            let chunks = src.split('.').map(parseUInt)
            if chunks.len == 4 and chunks.allIt(it < uint8.high): true else: false
        except: false

    proc isPort(src: string): bool =
        result = try: (if src.parseUInt < 65536: true else: false)
        except: false

    proc isCreds(src: string): bool =
        let creds = src.split(':')
        if creds.len == 2 and creds[1] == creds[1].strip(): return true

    proc first_match(sample: seq[string], tester: proc(src: string): bool, def_idx = -1): int {.inline.} = 
        for idx, elem in sample: (if elem.tester: return idx)
        return def_idx

    proc mapTrio(row: seq[string], map: LexTrio): LexMap =
        (row[map.ip], row[map.port], row[map.creds])

    proc newTrio(sample: seq[string], defs: LexTrio = (-1, -1, -1)): LexTrio =
        (sample.first_match(isIP,defs.ip), sample.first_match(isPort,defs.port), sample.first_match(isCreds,defs.creds))

    proc find_lexable(root: XmlNode): tuple[kind: string, map: LexMap] =
        if root.attrs != nil:
            let trio = toSeq(root.attrs.values).newTrio (-1, -1, 0)
            if trio.ip > -1 and trio.port > -1: return (root.tag, toSeq(root.attrs.keys).mapTrio trio)
        for child in root: 
            let recurse = child.find_lexable()
            if recurse.kind != "": return recurse
# -----------------------
when not defined(DataList):
    type DataList* = seq[UniData]

    # --Methods goes here:
    proc grab_xml(file: string): DataList {.thread.} =
        try:
            let
                root                = file.loadXml
                (kind, map)         = root.find_lexable
                (ip, port, spoof)   = map
            return root.findAll(kind).mapIt compose(it.attr(ip), it.attr(port), it.attr("user")&":"&it.attr("password"))
        except: echo getCurrentExceptionMsg()

    proc grab_html(file: string): DataList {.thread.} =
        # -Aux proc.
        proc find_uris(root: XmlNode): seq[Uri] =
            try:
                let txt = root.innerText.split(' ')
                var uri = txt[0].parseUri
                if uri.hostname.isIP: 
                    if txt.len > 1: (uri.username, uri.password) = txt[1].strip(true, true, {' ', '(', ')'}).split(':')
                    result &= uri
                for child in root: result &= child.find_uris()
            except: discard
        # -Actual parsing.
        try:
            return file.loadHtml.find_uris.deduplicate.mapIt compose(it.hostname, it.port, it.username&":"&it.password)
        except: echo getCurrentExceptionMsg()

    proc grab_csv(file: string): DataList {.thread.} =
        try:
            var csv: CsvParser
            csv.open(file, ';')
            csv.readHeaderRow()
            let trio = csv.row.newTrio((-1, 1, 4))
            let (ip, port, creds) = if trio.ip == -1: # Was it header ?
                discard csv.readRow(); csv.row.newTrio((0, 1, 4))
            else: trio                                # ...No ? Even better then.
            while true:
                result.add compose(csv.row[ip], csv.row[port], csv.row[creds])
                if not csv.readRow(): break
        except: echo getCurrentExceptionMsg()

    proc grab_txt(file: string): DataList {.thread.} =
        try:
            let 
                feed    = toSeq(lines(file))
                expcam  = feed.filterIt(0 <= it.find "[92m[+]The ")
            if expcam.len > 0: # If it was expcamera log...
                let data = expcam.mapIt(it.split(',').mapIt(it.split(":")[1]))
                var zip: seq[seq[string]]
                for idx, elem in data: # Zipping stuff together.
                    if idx mod 2 == 1: zip.add data[idx-1]; zip[^1][^1] &= ":" & elem[^1]
                let (ip, port, creds) = zip[0].newTrio
                return zip.mapIt compose(it[ip], it[port], it[creds])
        except: echo getCurrentExceptionMsg()

    proc grab*(feed: string, recursive = false): DataList =
        var grab_res: seq[FlowVar[DataList]]
        for (mask, prc) in [("xml", grab_xml), ("html", grab_html), ("csv", grab_csv), ("txt", grab_txt)]:
            for file in feed.joinPath("/*."&mask).walkFiles: grab_res.add spawn(prc(file))
        for res in grab_res: result &= ^res
        if recursive: (for dir in feed.walkDirs(): result &= dir.grab(true))
        result.deduplicate()

    proc raw*(self: DataList, add_port = true, add_creds = true, http_style = true): seq[string] =
        for ud in self: result.add(ud.raw(add_port, add_creds, http_style))

    proc check*(self: DataList): seq[Future[string]] =
        for ud in self: result.add(ud.check)

    proc wait*(self: seq[Future[string]]): seq[string] {.discardable.} =
        for future in self:
            try:
                while not future.finished: poll()
                result.add(future.read())
            except: discard
#.}

# --Extra--
getAppFilename().splitFile.dir.setCurrentDir
when isMainModule: echo grab("./feed").raw()