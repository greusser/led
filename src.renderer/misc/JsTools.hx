package misc;

import sortablejs.*;
import sortablejs.Sortable;

class JsTools {
	public static function makeSortable(jSortable:js.jquery.JQuery, ?jScrollRoot:js.jquery.JQuery, ?group:String, anim=true, onSort:(event:SortableDragEvent)->Void) {
		if( jSortable.length!=1 )
			N.error("Used sortable on a set of "+jSortable.length+" element(s)");
		jSortable.addClass("sortable");

		// Base settings
		var settings : SortableOptions = {
			onStart: function(ev) {
				App.ME.jBody.addClass("sorting");
				new J(ev.item).addClass("dragging");
			},
			onEnd: function(ev) {
				App.ME.jBody.removeClass("sorting");
				new J(ev.item).removeClass("dragging");
			},
			onSort: function(ev) {
				if( ev.oldIndex!=ev.newIndex || ev.from!=ev.to )
					onSort(ev);
				else
					new J(ev.item).click();
			},
			group: group,
			scroll: jScrollRoot!=null ? jScrollRoot.get(0) : jSortable.get(0),
			scrollSpeed: 40,
			scrollSensitivity: 140,
			filter: ".fixed",
			animation: anim ? 100 : 0,
		}

		// Custom handle
		if( jSortable.children().children(".sortHandle").length>0 ) {
			settings.handle = ".sortHandle";
			jSortable.addClass("customHandle");
		}

		Sortable.create( jSortable.get(0), settings);
	}


	public static function focusScrollableList(jList:js.jquery.JQuery, jElem:js.jquery.JQuery) {
		var targetY = jElem.position().top + jList.scrollTop();

		if( jList.css("position")=="static" )
			jList.css("position", "relative");

		targetY -= jList.outerHeight()*0.5;
		targetY = M.fclamp( targetY, 0, jList.prop("scrollHeight")-jList.outerHeight() );

		jList.scrollTop(targetY);
	}


	public static function prepareProjectFile(p:led.Project) : { bytes:haxe.io.Bytes, json:led.Json.ProjectJson } {
		var json = p.toJson();
		var jsonStr = dn.JsonPretty.stringify(p.minifyJson, json, Const.JSON_HEADER);

		return {
			bytes: haxe.io.Bytes.ofString( jsonStr ),
			json: json,
		}
	}

	public static function createLayerTypeIcon2(type:led.LedTypes.LayerType) : js.jquery.JQuery {
		var icon = new J('<span class="icon"/>');
		icon.addClass( switch type {
			case IntGrid: "intGrid";
			case AutoLayer: "autoLayer";
			case Entities: "entity";
			case Tiles: "tile";
		});
		return icon;
	}

	public static function createLayerTypeIconAndName(type:led.LedTypes.LayerType) : js.jquery.JQuery {
		var wrapper = new J('<span class="layerType"/>');

		wrapper.append( createLayerTypeIcon2(type) );

		var name = new J('<span class="name"/>');
		name.appendTo(wrapper);
		name.text( L.getLayerType(type) );

		return wrapper;
	}

	public static function createFieldTypeIcon(type:led.LedTypes.FieldType, withName=true, ?ctx:js.jquery.JQuery) : js.jquery.JQuery {
		var icon = new J("<span/>");
		icon.addClass("icon fieldType");
		icon.addClass(type.getName());
		if( withName )
			icon.append('<span class="typeName">'+L.getFieldType(type)+'</span>');
		icon.append('<span class="typeIcon">'+L.getFieldTypeShortName(type)+'</span>');

		if( ctx!=null )
			icon.appendTo(ctx);

		return icon;
	}

	public static function createTile(td:led.def.TilesetDef, tileId:Int, size:Int) {
		var jCanvas = new J('<canvas></canvas>');
		jCanvas.attr("width",td.tileGridSize);
		jCanvas.attr("height",td.tileGridSize);
		jCanvas.css("width", size+"px");
		jCanvas.css("height", size+"px");
		td.drawTileToCanvas(jCanvas, tileId);
		return jCanvas;
	}


	public static function createEntityPreview(project:led.Project, ed:led.def.EntityDef, sizePx=24) {
		var jWrapper = new J('<div class="entityPreview icon"></div>');
		jWrapper.css("width", sizePx+"px");
		jWrapper.css("height", sizePx+"px");

		var scale = sizePx / M.fmax(ed.width, ed.height);

		var jCanvas = new J('<canvas></canvas>');
		jCanvas.appendTo(jWrapper);
		jCanvas.attr("width", ed.width*scale);
		jCanvas.attr("height", ed.height*scale);

		var cnv = Std.downcast( jCanvas.get(0), js.html.CanvasElement );
		var ctx = cnv.getContext2d();

		switch ed.renderMode {
			case Rectangle:
				ctx.fillStyle = C.intToHex(ed.color);
				ctx.fillRect(0, 0, ed.width*scale, ed.height*scale);

			case Cross:
				ctx.strokeStyle = C.intToHex(ed.color);
				ctx.lineWidth = 5 * js.Browser.window.devicePixelRatio;
				ctx.moveTo(0,0);
				ctx.lineTo(ed.width*scale, ed.height*scale);
				ctx.moveTo(0,ed.height*scale);
				ctx.lineTo(ed.width*scale, 0);
				ctx.stroke();

			case Ellipse:
				ctx.fillStyle = C.intToHex(ed.color);
				ctx.beginPath();
				ctx.ellipse(
					ed.width*0.5*scale, ed.height*0.5*scale,
					ed.width*0.5*scale, ed.height*0.5*scale,
					0, 0, M.PI*2
				);
				ctx.fill();

			case Tile:
				ctx.fillStyle = C.intToHex(ed.color)+"66";
				ctx.beginPath();
				ctx.rect(0, 0, Std.int(ed.width*scale), Std.int(ed.height*scale));
				ctx.fill();

				if( ed.isTileDefined() ) {
					var td = project.defs.getTilesetDef(ed.tilesetId);
					var x = 0;
					var y = 0;
					var scaleX = 1.;
					var scaleY = 1.;
					switch ed.tileRenderMode {
						case Stretch:
							scaleX = scale * ed.width / td.tileGridSize;
							scaleY = scale * ed.height / td.tileGridSize;

						case Crop:
							scaleX = scaleY = scale;
							x = Std.int(ed.width*ed.pivotX*scale - td.tileGridSize*ed.pivotX*scale);
							y = Std.int(ed.height*ed.pivotY*scale - td.tileGridSize*ed.pivotY*scale);
					}
					td.drawTileToCanvas( jCanvas, ed.tileId, x, y, scaleX, scaleY );
				}
		}

		return jWrapper;
	}


	public static function createPivotEditor( curPivotX:Float, curPivotY:Float, ?inputName:String, ?bgColor:UInt, onPivotChange:(pivotX:Float, pivotY:Float)->Void ) {
		var pivots = new J("xml#pivotEditor").children().first().clone();

		pivots.find("input[type=radio]").attr("name", inputName==null ? "pivot" : inputName);

		if( bgColor!=null )
			pivots.find(".bg").css( "background-color", C.intToHex(bgColor) );
		else
			pivots.find(".bg").hide();

		pivots.find("input[type=radio][value='"+curPivotX+" "+curPivotY+"']").prop("checked",true);

		pivots.find("input[type=radio]").each( function(idx:Int, elem) {
			var r = new J(elem);
			r.change( function(ev) {
				var rawPivots = r.val().split(" ");
				onPivotChange( Std.parseFloat( rawPivots[0] ), Std.parseFloat( rawPivots[1] ) );
			});
		});

		return pivots;
	}

	public static function createIcon(id:String) {
		var jIcon = new J('<span class="icon"/>');
		jIcon.addClass(id);
		return jIcon;
	}




	static var _fileCache : Map<String,String> = new Map();
	public static function clearFileCache() {
		_fileCache = new Map();
	}

	public static function getHtmlTemplate(name:String, ?vars:Dynamic) : Null<String> {
		if( !_fileCache.exists(name) ) {
			App.LOG.fileOp("Loading HTML template "+name);
			var path = dn.FilePath.fromFile(App.APP_ASSETS_DIR + "tpl/" + name);
			path.extension = "html";

			if( !fileExists(path.full) )
				throw "File not found "+path.full;

			_fileCache.set( name, readFileString(path.full) );
		}
		else
			App.LOG.fileOp("Reading HTML template "+name+" from cache");

		var raw = _fileCache.get(name);
		if( vars!=null ) {
			for(k in Reflect.fields(vars))
				raw = StringTools.replace( raw, '::$k::', Reflect.field(vars,k) );
		}

		return raw;
	}


	static function getTmpFileInput() {
		var input = new J("input#tmpFileInput");
		if( input.length==0 ) {
			input = new J("<input/>");
			input.attr("type","file");
			input.attr("id","tmpFileInput");
			input.appendTo( App.ME.jBody );
			input.hide();
		}
		input.off();
		input.removeAttr("accept");
		input.removeAttr("nwsaveas");

		input.click( function(ev) {
			input.val("");
		});

		return input;
	}


	public static inline function createKeyInLabel(label:String) {
		var r = ~/(.*)\[(.*)\](.*)/gi;
		if( !r.match(label) )
			return new J('<span>$label</span>');
		else {
			var j = new J("<span/>");
			j.append(r.matched(1));
			j.append( new J('<span class="key">'+r.matched(2)+'</span>') );
			j.append(r.matched(3));
			return j;
		}
	}

	public static inline function createKey(?kid:Int, ?keyLabel:String) {
		if( kid!=null )
			keyLabel = K.getKeyName(kid);

		if( keyLabel.toLowerCase()=="shift" )
			keyLabel = "⇧";
		else if ( App.isMac() && keyLabel.toLowerCase()=="ctrl")
			keyLabel = "⌘";

		return new J('<span class="key">$keyLabel</span>');
	}

	public static function parseKeys(rawKeys:String) : Array<js.jquery.JQuery> {
		var jKeys = [];

		for(k in rawKeys.split(" ")) {
			if( k==null || k.length==0 )
				continue;


			jKeys.push( switch k.toLowerCase() {
				case "mouseleft": new J('<span class="icon mouseleft"></span>');
				case "mouseright": new J('<span class="icon mouseright"></span>');
				case "mousewheel": new J('<span class="icon mousewheel"></span>');

				case "+", "-", "to" : new J('<span class="misc">$k</span>');

				case k.charAt(0) => "(": new J("<span/>").append(k);
				case k.charAt(k.length-1) => ")": new J("<span/>").append(k);

				case _:
					var jKey = new J('<span class="key">${k.toUpperCase()}</span>');
					switch k.toLowerCase() {
						case "shift", "alt" : jKey.addClass( k.toLowerCase() );
						case "ctrl" : jKey.addClass( App.isMac() ? 'meta' : k.toLowerCase() );
						case _:
					}
					jKey;
			});
		}
		return jKeys;
	}


	public static function parseComponents(jCtx:js.jquery.JQuery) {
		// (i) Info bubbles
		jCtx.find(".info").each( function(idx, e) {
			var jThis = new J(e);

			if( jThis.data("str")==null ) {
				if( jThis.hasClass("identifier") )
					jThis.data( "str", L.t._("An identifier should be UNIQUE (in this context) and can only contain LETTERS, NUMBERS or UNDERSCORES (ie. \"_\").") );
				else
					jThis.data("str", jThis.text());
				jThis.empty();
			}
			ui.Tip.attach(jThis, jThis.data("str"), "infoTip");
		});

		// External links
		var links = jCtx.find("a[href^=http], button[href]");
		links.each( function(idx,e) {
			var link = new J(e);
			var url = link.attr("href");
			if( url=="#" )
				return;

			var cleanUrlReg = ~/(http[s]*:\/\/)*(.*)/g;
			cleanUrlReg.match(url);
			var displayUrl = cleanUrlReg.matched(2);
			var cut = 40;
			if( displayUrl.length>cut )
				displayUrl = displayUrl.substr(0,cut)+"...";
			ui.Tip.attach(link, displayUrl, "link", true);
			link.click( function(ev) {
				ev.preventDefault();
				electron.Shell.openExternal(url);
			});
		});


		// Auto tool-tips
		jCtx.find("[title], [data-title]").each( function(idx,e) {
			var jThis = new J(e);
			var tip = jThis.attr("data-title");
			if( tip==null ) {
				tip =  jThis.attr("title");
				jThis.removeAttr("title");
				jThis.attr("data-title", tip);
			}

			// Parse key shortcut
			var keys = [];
			if( jThis.attr("keys")!=null ) {
				var rawKeys = jThis.attr("keys").split("+").map( function(k) return StringTools.trim(k).toLowerCase() );
				for(k in rawKeys) {
					switch k {
						case "ctrl" : keys.push(K.CTRL);
						case "shift" : keys.push(K.SHIFT);
						case "alt" : keys.push(K.ALT);
						case _ :
							var funcReg = ~/[fF]([0-9]+)/;
							if( k.length==1 ) {
								var cid = k.charCodeAt(0);
								if( cid>="a".code && cid<="z".code )
									keys.push( cid - "a".code + K.A );
							}
							else if( funcReg.match(k) )
								keys.push( K.F1 + Std.parseInt(funcReg.matched(1)) - 1 );
					}
				}
			}

			ui.Tip.attach( jThis, tip, keys );
		});

		// Tabs
		jCtx.find("ul.tabs").each( function(idx,e) {
			var jTabs = new J(e);
			jTabs.find("li").click( function(ev:js.jquery.Event) {
				var jTab = ev.getThis();
				jTabs.find("li").removeClass("active");
				jTab.addClass("active");
				jTabs
					.siblings(".tab").hide()
					.filter("[section="+jTab.attr("section")+"]").show();
			});
			jTabs.find("li:first").click();
		});
	}


	public static function makePath(path:String, ?pathColor:UInt) {
		path = StringTools.replace(path,"\\","/");
		var parts = path.split("/").map( function(p) {
			if( pathColor==null )
				return '<span style="color: ${ C.intToHex(C.fromStringLight(p)) }">$p</span>';
			else
				return '<span style="color: ${ C.intToHex(pathColor) }">$p</span>';
		});
		var e = new J( parts.join('<span class="slash">/</span>') );
		return e.wrapAll('<div class="path"/>').parent();
	}


	// *** File API (node) **************************************

	public static function fileExists(path:String) {
		if( path==null )
			return false;
		else {
			js.node.Require.require("fs");
			return js.node.Fs.existsSync(path);
		}
	}

	public static function readFileString(path:String) : Null<String> {
		if( !fileExists(path) )
			return null;
		else
			return js.node.Fs.readFileSync(path).toString();
	}

	public static function readFileBytes(path:String) : Null<haxe.io.Bytes> {
		if( !fileExists(path) )
			return null;
		else
			return js.node.Fs.readFileSync(path).hxToBytes();
	}

	public static function writeFileBytes(path:String, bytes:haxe.io.Bytes) {
		js.node.Require.require("fs");
		js.node.Fs.writeFileSync( path, js.node.Buffer.hxFromBytes(bytes) );
	}

	public static function createDir(path:String) {
		if( fileExists(path) )
			return;
		js.node.Require.require("fs");
		js.node.Fs.mkdirSync(path);
	}

	public static function emptyDir(path:String) {
		js.node.Require.require("fs");
		if( !fileExists(path) )
			return;

		for(f in js.node.Fs.readdirSync(path)) {
			var fp = dn.FilePath.fromDir(path);
			fp.fileWithExt = f;
			trace(fp);
			if( js.node.Fs.lstatSync(fp.full).isFile() )
				js.node.Fs.unlinkSync(fp.full);
		}
	}

	public static function getExeDir() {
		var path = electron.renderer.IpcRenderer.sendSync("getExeDir");
		#if debug
		path = getAppResourceDir()+"/app";
		#end
		return dn.FilePath.fromFile( path ).useSlashes().directory;
	}

	public static function getAppResourceDir() {
		var path = electron.renderer.IpcRenderer.sendSync("getAppResourceDir");
		return dn.FilePath.fromDir( path ).useSlashes().directory;
	}

	public static function getCwd() {
		var path = electron.renderer.IpcRenderer.sendSync("getCwd");
		return dn.FilePath.fromDir( path ).useSlashes().directory;
	}

	public static function exploreToFile(filePath:String) {
		var fp = dn.FilePath.fromFile(filePath);
		if( isWindows() )
			fp.useBackslashes();

		if( !fileExists(fp.full) )
			fp.fileWithExt = null;

		electron.Shell.showItemInFolder(fp.full);
	}

	public static function makeExploreLink(filePath:String) {
		var a = new J('<a class="exploreTo"/>');
		a.click( function(ev) {
			ev.preventDefault();
			ev.stopPropagation();
			exploreToFile(filePath);
		});
		return a;
	}

	public static function isWindows() {
		return js.Node.process.platform.toLowerCase().indexOf("win")==0;
	}

	public static function removeClassReg(jElem:js.jquery.JQuery, reg:EReg) {
		jElem.removeClass( function(idx, classes) {
			var all = [];
			while( reg.match(classes) ) {
				all.push( reg.matched(0) );
				classes = reg.matchedRight();
			}
			return all.join(" ");
		});
	}

	public static function clearCanvas(jCanvas:js.jquery.JQuery) {
		if( !jCanvas.is("canvas") )
			throw "Not a canvas";

		var cnv = Std.downcast( jCanvas.get(0), js.html.CanvasElement );
		cnv.getContext2d().clearRect(0,0, cnv.width, cnv.height);
	}


	public static function createTilePicker(
		tilesetId: Null<Int>,
		mode: TilePickerMode=MultiTiles,
		tileIds: Array<Int>,
		onPick: (tileIds:Array<Int>)->Void
	) {
		var jTileCanvas = new J('<canvas class="tile"></canvas>');

		if( tilesetId!=null ) {
			jTileCanvas.addClass("active");
			var td = Editor.ME.project.defs.getTilesetDef(tilesetId);

			if( tileIds.length==0 ) {
				// No tile selected
				jTileCanvas.addClass("empty");
			}
			else if( mode!=RectOnly ) {
				// Single/random tiles
				jTileCanvas.removeClass("empty");
				jTileCanvas.attr("width", td.tileGridSize);
				jTileCanvas.attr("height", td.tileGridSize);
				td.drawTileToCanvas(jTileCanvas, tileIds[0]);
				if( tileIds.length>1 && mode!=RectOnly ) {
					// Cycling animation among multiple tiles
					jTileCanvas.addClass("multi");
					var idx = 0;
					Editor.ME.createChildProcess(function(p) {
						if( p.cd.hasSetS("tick",0.2) )
							return;

						if( jTileCanvas.parents("body").length==0 ) {
							p.destroy();
							return;
						}

						idx++;
						if( idx>=tileIds.length )
							idx = 0;

						td.drawTileToCanvas(jTileCanvas, tileIds[idx]);
					});
				}
			}
			else {
				// Tile group stamp
				var bounds = td.getTileGroupBounds(tileIds);
				var wid = M.imax(bounds.wid, 1);
				var hei = M.imax(bounds.hei, 1);
				jTileCanvas.attr("width", td.tileGridSize * wid );
				jTileCanvas.attr("height", td.tileGridSize * hei );
				var scale = M.fmin(1, 48 / ( M.fmax(wid, hei)*td.tileGridSize ) );
				jTileCanvas.css("width", td.tileGridSize * wid * scale );
				jTileCanvas.css("height", td.tileGridSize * hei * scale );

				for(tid in tileIds) {
					var tcx = td.getTileCx(tid);
					var tcy = td.getTileCy(tid);
					td.drawTileToCanvas(jTileCanvas, tid, (tcx-bounds.left)*td.tileGridSize, (tcy-bounds.top)*td.tileGridSize);
				}
			}

			// Open picker
			jTileCanvas.click( function(ev) {
				var m = new ui.Modal();
				m.addClass("singleTilePicker");

				var tp = new ui.TilesetPicker(m.jContent, td, mode);
				tp.setSelectedTileIds(tileIds);
				if( mode==SingleTile )
					tp.onSingleTileSelect = function(tileId) {
						m.close();
						onPick([tileId]);
					}
				else
					m.onCloseCb = function() {
						onPick( tp.getSelectedTileIds() );
					}
				tp.focusOnSelection(true);
			});
		}
		else {
			// Invalid tileset
			jTileCanvas.addClass("empty");
		}

		return jTileCanvas;
	}


	public static function createAutoPatternGrid(
		rule: led.def.AutoLayerRuleDef,
		sourceDef: led.def.LayerDef,
		layerDef: led.def.LayerDef,
		previewMode=false,
		?explainCell: (desc:Null<String>)->Void,
		?onClick: (cx:Int, cy:Int, button:Int)->Void
	) {
		var jGrid = new J('<div class="autoPatternGrid"/>');
		jGrid.addClass("size-"+rule.size);

		if( onClick!=null )
			jGrid.addClass("editable");

		if( previewMode )
			jGrid.addClass("preview");

		function addExplain(jTarget:js.jquery.JQuery, desc:String) {
			if( explainCell==null )
				return;

			jTarget
				.mouseover( function(_) {
					explainCell(desc);
				})
				.mouseout( function(_) {
					explainCell(null);
				});
		}

		var idx = 0;
		for(cy in 0...rule.size)
		for(cx in 0...rule.size) {
			var coordId = cx+cy*rule.size;
			var isCenter = cx==Std.int(rule.size/2) && cy==Std.int(rule.size/2);

			var jCell = new J('<div class="cell"/>');
			jCell.appendTo(jGrid);
			if( onClick!=null )
				jCell.addClass("editable");

			// Center
			if( isCenter ) {
				switch rule.tileMode {
					case Single:
						jCell.addClass("center");

					case Stamp:
						var jStampPreview = new J('<div class="stampPreview"/>');
						jStampPreview.appendTo(jCell);
						var previewWid = 32;
						var previewHei = 32;
						if( rule.tileIds.length>1 ) {
							var td = Editor.ME.project.defs.getTilesetDef( layerDef.autoTilesetDefUid );
							if( td!=null ) {
								var bounds = td.getTileGroupBounds(rule.tileIds);
								if( bounds.wid>1 )
									previewWid = Std.int( previewWid * 1.9 );
								if( bounds.hei>1 )
									previewHei = Std.int( previewHei * 1.9 );
							}
						}
						jStampPreview.css("width", previewWid + "px");
						jStampPreview.css("height", previewHei + "px");
						jStampPreview.css("left", ( rule.pivotX * (32-previewWid) ) + "px");
						jStampPreview.css("top", ( rule.pivotY * (32-previewHei) ) + "px");
				}
				if( previewMode ) {
					var td = Editor.ME.project.defs.getTilesetDef( layerDef.autoTilesetDefUid );
					if( td!=null ) {
						var jTile = createTile(td, rule.tileIds[0], 32);
						jCell.append(jTile);
						jCell.addClass("tilePreview");
						if( rule.tileIds.length>1 )
							jTile.addClass("multi");
					}
				}
			}

			// Cell color
			if( !isCenter || !previewMode ) {
				var v = rule.get(cx,cy);
				if( v!=0 ) {
					if( v>0 ) {
						if( M.iabs(v)-1 == Const.AUTO_LAYER_ANYTHING ) {
							jCell.addClass("anything");
							addExplain(jCell, 'This cell should contain any IntGrid value to match.');
						}
						else {
							jCell.css("background-color", C.intToHex( sourceDef.getIntGridValueDef(M.iabs(v)-1).color ) );
							addExplain(jCell, 'This cell should contain "${sourceDef.getIntGridValueDisplayName(M.iabs(v)-1)}" to match.');
						}
					}
					else {
						jCell.addClass("not").append('<span class="cross"></span>');
						if( M.iabs(v)-1 == Const.AUTO_LAYER_ANYTHING ) {
							jCell.addClass("anything");
							addExplain(jCell, 'This cell should NOT contain any IntGrid value to match.');
						}
						else {
							jCell.css("background-color", C.intToHex( sourceDef.getIntGridValueDef(M.iabs(v)-1).color ) );
							addExplain(jCell, 'This cell should NOT contain "${sourceDef.getIntGridValueDisplayName(M.iabs(v)-1)}" to match.');
						}
					}
				}
				else {
					addExplain(jCell, 'This cell content doesn\'t matter.');
					jCell.addClass("empty");
				}
			}

			// Edit grid value
			if( onClick!=null )
				jCell.mousedown( function(ev) {
					onClick(cx,cy, ev.button);
				});

			idx++;
		}

		return jGrid;
	}
}
