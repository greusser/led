package ui;

class EntityInstanceEditor extends dn.Process {
	public static var CURRENT : Null<EntityInstanceEditor> = null;

	var jPanel : js.jquery.JQuery;
	var ei : led.inst.EntityInstance;
	var link : h2d.Graphics;

	private function new(ei:led.inst.EntityInstance) {
		super(Editor.ME);

		if( CURRENT!=null )
			close();

		CURRENT = this;
		this.ei = ei;
		Editor.ME.ge.addGlobalListener(onGlobalEvent);

		link = new h2d.Graphics();
		Editor.ME.root.add(link, Const.DP_UI);

		jPanel = new J('<div class="entityInstanceEditor"/>');
		App.ME.jBody.append(jPanel);

		updateForm();
	}

	override function onDispose() {
		super.onDispose();

		jPanel.remove();
		jPanel = null;

		link.remove();
		link = null;

		ei = null;

		if( CURRENT==this )
			CURRENT = null;
		Editor.ME.ge.removeListener(onGlobalEvent);
	}

	function onGlobalEvent(ge:GlobalEvent) {
		switch ge {
			case ProjectSettingsChanged, EntityDefChanged, EntityFieldDefChanged(_), EntityFieldSorted:
				if( ei==null || ei.def==null )
					destroy();
				else
					updateForm();

			case LayerInstanceSelected:
				close();

			case EnumDefRemoved, EnumDefChanged, EnumDefSorted, EnumDefValueRemoved:
				updateForm();

			case EntityInstanceRemoved(ei):
				if( ei==this.ei )
					close();

			case EntityInstanceChanged(ei):
				if( ei==this.ei )
					updateForm();

			case LayerInstanceRestoredFromHistory(_), LevelRestoredFromHistory:
				close(); // TODO do softer refresh


			case ViewportChanged :
				updateForm();

			case _:
		}
	}

	function renderLink() {
		jPanel.css("border-color", C.intToHex(ei.def.color));
		var win = js.Browser.window;
		var render = Editor.ME.levelRender;
		link.clear();
		link.lineStyle(4*win.devicePixelRatio, ei.def.color, 0.33);
		link.moveTo(
			render.levelToUiX(ei.x),
			render.levelToUiY(ei.y)
		);
		link.lineTo(
			Editor.ME.canvasWid() - jPanel.outerWidth()*win.devicePixelRatio,
			Editor.ME.canvasHei()*0.5
		);
	}

	public static function openFor(ei:led.inst.EntityInstance) {
		if( existsFor(ei) )
			return CURRENT;
		else
			return new EntityInstanceEditor(ei);
	}

	public static inline function existsFor(ei:led.inst.EntityInstance) {
		return isOpen() && CURRENT.ei==ei;
	}

	public static inline function isOpen() {
		return CURRENT!=null && !CURRENT.destroyed;
	}

	public static function close() {
		if( isOpen() ) {
			CURRENT.destroy();
			CURRENT = null;
			return true;
		}
		else
			return false;
	}

	function onFieldChange(keepEditingPoints=false) {
		if( !keepEditingPoints )
			Editor.ME.clearSpecialTool();

		updateForm();
		var editor = Editor.ME;
		editor.curLevelHistory.saveLayerState( editor.curLayerInstance );
		editor.curLevelHistory.setLastStateBounds( ei.left, ei.top, ei.def.width, ei.def.height );
		editor.ge.emit( EntityInstanceFieldChanged(ei) );
	}


	function hideInputIfDefault(arrayIdx:Int, input:js.jquery.JQuery, fi:led.inst.FieldInstance) {
		input.off(".def").removeClass("usingDefault");

		if( fi.isUsingDefault(arrayIdx) ) {
			if( input.is("button") ) {
				// Button input
				if( fi.def.type!=F_Point || fi.def.canBeNull )
					input.addClass("gray usingDefault");
			}
			else if( input.is("[type=color]") ) {
				// Color input
				input.addClass("usingDefault");
				input.text("default");
			}
			else if( input.is(".colorWrapper") ) {
				// Wrapped color input
				input.addClass("usingDefault");
			}
			else if( !input.is("select") ) {
				// General INPUT
				var jRep = new J('<a class="usingDefault" href="#"/>');
				if( input.is("[type=checkbox]") ) {
					var chk = new J('<input type="checkbox"/>');
					chk.prop("checked", fi.getBool(arrayIdx));
					jRep.append( chk.wrap('<span class="value"/>').parent() );
					jRep.addClass("checkbox");
				}
				else
					jRep.append('<span class="value">${fi.getForDisplay(arrayIdx)}</span>');
				jRep.append('<span class="label">Default</span>');
				jRep.on("click.def", function(ev) {
					ev.preventDefault();
					jRep.remove();
					input.show().focus();
					if( input.is("[type=checkbox]") ) {
						input.prop("checked", !fi.getBool(arrayIdx));
						input.change();
					}
				});
				jRep.insertBefore(input);
				input.hide();

				input.on("blur.def", function(ev) {
					jRep.remove();
					hideInputIfDefault(arrayIdx, input,fi);
				});
			}
			else if( input.is("select") && ( fi.getEnumValue(arrayIdx)!=null || fi.def.canBeNull ) ) {
				// SELECT case
				input.addClass("usingDefault");
				input.on("click.def", function(ev) {
					input.removeClass("usingDefault");
				});
				input.on("blur.def", function(ev) {
					hideInputIfDefault(arrayIdx, input,fi);
				});
			}
		}
		else if( fi.def.type==F_Color || fi.def.type==F_Bool || fi.def.type==F_Point && fi.def.canBeNull ) {
			// Require a "Reset to default" link
			var span = input.wrap('<span class="inputWithDefaultOption"/>').parent();
			span.find("input").wrap('<span class="value"/>');
			var defLink = new J('<a class="reset" href="#">[ Reset ]</a>');
			defLink.appendTo(span);
			defLink.on("click.def", function(ev) {
				fi.parseValue(arrayIdx, null);
				onFieldChange();
				ev.preventDefault();
			});
		}
	}


	function startPointsEditing(fi:led.inst.FieldInstance, editIdx:Int) {
		jPanel.addClass("picking");

		var t = new tool.PickPoint();

		t.pickOrigin = { cx:ei.getCx(Editor.ME.curLayerDef), cy:ei.getCy(Editor.ME.curLayerDef), color:ei.def.color }

		// Connect to last of path
		if( fi.def.isArray && fi.def.editorDisplayMode==PointPath ) {
			var pt = fi.getPointGrid( editIdx-1 );
			if( pt!=null )
				t.pickOrigin = { cx:pt.cx, cy:pt.cy, color:ei.def.color }
		}

		// Picking of a point
		t.onPick = function(m) {
			if( this.destroyed )
				return;

			if( fi.def.isArray && editIdx>=fi.getArrayLength()-1 ) {
				// Append points in an array
				fi.parseValue(editIdx, m.cx+Const.POINT_SEPARATOR+m.cy);
				editIdx = fi.getArrayLength();

				if( fi.def.editorDisplayMode==PointPath ) {
					// Connect to path previous
					var pt = fi.getPointGrid( editIdx-1 );
					if( pt!=null )
						t.pickOrigin = { cx:pt.cx, cy:pt.cy, color:ei.def.color }
				}
			}
			else {
				// Edit a single point
				Editor.ME.clearSpecialTool();
				fi.parseValue(editIdx, m.cx+Const.POINT_SEPARATOR+m.cy);
			}
			onFieldChange(true);
			jPanel.addClass("picking");
		}

		// Tool stopped
		t.onDisposeCb = function() {
			if( !destroyed )
				updateForm();
		}

		Editor.ME.setSpecialTool(t);
	}


	function createInputFor(fi:led.inst.FieldInstance, arrayIdx:Int, jTarget:js.jquery.JQuery) {
		switch fi.def.type {
			case F_Int:
				var input = new J("<input/>");
				input.appendTo(jTarget);
				input.attr("type","text");
				input.attr("placeholder", fi.def.getDefault()==null ? "(null)" : fi.def.getDefault());
				if( !fi.isUsingDefault(arrayIdx) )
					input.val( Std.string(fi.getInt(arrayIdx)) );
				input.change( function(ev) {
					fi.parseValue( arrayIdx, input.val() );
					onFieldChange();
				});
				hideInputIfDefault(arrayIdx, input, fi);

			case F_Color:
				var cHex = fi.getColorAsHexStr(arrayIdx);

				var jWrapper = new J('<label class="colorWrapper"/>');
				jWrapper.appendTo(jTarget);
				jWrapper.css({
					backgroundColor: cHex,
					borderColor: C.intToHex( C.toWhite( C.hexToInt(cHex), 0.2 ) ),
				});
				if( fi.isUsingDefault(arrayIdx) )
					jWrapper.append("(default)");

				var input = new J("<input/>");
				input.appendTo(jWrapper);
				input.attr("type","color");
				input.addClass("advanced");
				input.val(cHex);
				input.change( function(ev) {
					fi.parseValue( arrayIdx, input.val() );
					onFieldChange();
				});

				hideInputIfDefault(arrayIdx, jWrapper, fi);

			case F_Float:
				var input = new J("<input/>");
				input.appendTo(jTarget);
				input.attr("type","text");
				input.attr("placeholder", fi.def.getDefault()==null ? "(null)" : fi.def.getDefault());
				if( !fi.isUsingDefault(arrayIdx) )
					input.val( Std.string(fi.getFloat(arrayIdx)) );
				input.change( function(ev) {
					fi.parseValue( arrayIdx, input.val() );
					onFieldChange();
				});
				hideInputIfDefault(arrayIdx, input, fi);

			case F_String:
				var input = new J("<input/>");
				input.appendTo(jTarget);
				input.attr("type","text");
				var def = fi.def.getStringDefault();
				input.attr("placeholder", def==null ? "(null)" : def=="" ? "(empty string)" : def);
				if( !fi.isUsingDefault(arrayIdx) )
					input.val( fi.getString(arrayIdx) );
				input.change( function(ev) {
					fi.parseValue( arrayIdx, input.val() );
					onFieldChange();
				});
				hideInputIfDefault(arrayIdx, input, fi);

			case F_Point:
				if( fi.valueIsNull(arrayIdx) && !fi.def.canBeNull || !fi.def.isArray ) {
					// Button mode
					var jPick = new J('<button/>');
					jPick.appendTo(jTarget);
					jPick.addClass("point");
					if( fi.valueIsNull(arrayIdx) && !fi.def.canBeNull ) {
						jPick.addClass("required");
						jPick.text( "Point required!" );
					}
					else
						jPick.text( fi.valueIsNull(arrayIdx) ? "--none--" : fi.getPointStr(arrayIdx) );
					jPick.click( function(_) {
						if( Editor.ME.isSpecialToolActive(tool.PickPoint) ) {
							// Cancel
							Editor.ME.clearSpecialTool();
							updateForm();
						}
						else {
							// Start picking
							jPick.text("Cancel");
							startPointsEditing(fi, arrayIdx);
						}
					});
				}
				else {
					// Text mode
					var jPoint = new J('<span class="point"/>');
					jPoint.appendTo(jTarget);
					jPoint.text( fi.getPointStr(arrayIdx) );
				}


			case F_Enum(name):
				var ed = Editor.ME.project.defs.getEnumDef(name);
				var select = new J("<select/>");
				select.appendTo(jTarget);

				// Null value
				if( fi.def.canBeNull || fi.getEnumValue(arrayIdx)==null ) {
					var opt = new J('<option/>');
					opt.appendTo(select);
					opt.attr("value","");
					if( fi.def.canBeNull )
						opt.text("-- null --");
					else {
						// SELECT shouldn't be null
						select.addClass("required");
						opt.text("[ Value required ]");
						select.click( function(ev) {
							select.removeClass("required");
							select.blur( function(ev) updateForm() );
						});
					}
					if( fi.getEnumValue(arrayIdx)==null )
						opt.attr("selected","selected");
				}

				for(v in ed.values) {
					var opt = new J('<option/>');
					opt.appendTo(select);
					opt.attr("value",v.id);
					opt.text(v.id);
					if( fi.getEnumValue(arrayIdx)==v.id && !fi.isUsingDefault(arrayIdx) )
						opt.attr("selected","selected");
				}

				select.change( function(ev) {
					var v = select.val()=="" ? null : select.val();
					fi.parseValue(arrayIdx, v);
					onFieldChange();
				});
				hideInputIfDefault(arrayIdx, select, fi);

			case F_Bool:
				var input = new J("<input/>");
				input.appendTo(jTarget);
				input.attr("type","checkbox");
				input.prop("checked",fi.getBool(arrayIdx));
				input.change( function(ev) {
					fi.parseValue( arrayIdx, Std.string( input.prop("checked") ) );
					onFieldChange();
				});

				hideInputIfDefault(arrayIdx, input, fi);
		}
	}


	function updateForm() {
		jPanel.empty();
		jPanel.removeClass("picking");
		if( ei==null ) {
			close();
			return;
		}

		var jHeader = new J('<header/>');
		jHeader.appendTo(jPanel);
		jHeader.append('<div>${ei.def.identifier}</div>');
		var jEdit = new J('<a class="edit">Edit</a>');
		jEdit.click( function(ev) {
			ev.preventDefault();
			new ui.modal.panel.EditEntityDefs(ei.def);
		});
		jHeader.append(jEdit);

		if( ei.def.fieldDefs.length==0 )
			jPanel.append('<div class="empty">This entity has no custom field.</div>');
		else {
			var form = new J('<ul class="form"/>');
			form.appendTo(jPanel);
			for(fd in ei.def.fieldDefs) {
				var fi = ei.getFieldInstance(fd);
				var li = new J("<li/>");
				li.attr("defUid", fd.uid);
				li.appendTo(form);
				li.append('<label>${fi.def.identifier}</label>');

				if( !fd.isArray ) {
					// Single value
					createInputFor(fi, 0, li);
				}
				else {
					// Array
					var jArray = new J('<div class="array"/>');
					jArray.appendTo(li);
					if( fd.arrayMinLength!=null && fi.getArrayLength()<fd.arrayMinLength
						|| fd.arrayMaxLength!=null && fi.getArrayLength()>fd.arrayMaxLength ) {
						var bounds : String =
							fd.arrayMinLength==fd.arrayMaxLength ? Std.string(fd.arrayMinLength)
							: fd.arrayMaxLength==null ? fd.arrayMinLength+"+"
							: fd.arrayMinLength+"-"+fd.arrayMaxLength;
						jArray.append('<div class="warning">Array should have $bounds value(s)</div>');
					}

					var jArrayInputs = new J('<ul class="values"/>');
					jArrayInputs.appendTo(jArray);

					var sortable = fi.def.type!=F_Point;
					for(i in 0...fi.getArrayLength()) {
						var li = new J('<li/>');
						li.appendTo(jArrayInputs);

						if( sortable )
							li.append('<div class="sortHandle"/>');

						createInputFor(fi, i, li);

						// "Remove" button
						var jRemove = new J('<button class="remove dark">x</button>');
						jRemove.appendTo(li);
						var idx = i;
						jRemove.click( function(_) {
							fi.removeArrayValue(idx);
							onFieldChange();
							updateForm();
						});
					}
					if( sortable )
						JsTools.makeSortable(jArrayInputs, function(ev:sortablejs.Sortable.SortableDragEvent) {
							fi.sortArrayValues(ev.oldIndex, ev.newIndex);
							onFieldChange();
						});

					// "Add" button
					if( fi.def.arrayMaxLength==null || fi.getArrayLength()<fi.def.arrayMaxLength ) {
						var jAdd = new J('<button class="add"/>');
						jAdd.text("Add "+fi.def.getShortDescription(false) );
						jAdd.appendTo(jArray);
						jAdd.click( function(_) {
							if( fi.def.type==F_Point ) {
								startPointsEditing(fi, fi.getArrayLength());
							}
							else {
								fi.addArrayValue();
								onFieldChange();
								updateForm();
							}
							var jArray = jPanel.find('[defuid=${fd.uid}] .array');
							switch fi.def.type {
								case F_Int, F_Float, F_String: jArray.find("a.usingDefault:last").click();
								case F_Bool:
								case F_Color:
								case F_Enum(enumDefUid):
									// see: https://stackoverflow.com/a/10453874
									// var select = jArray.find("select:last").get(0);
									// var ev : js.html.MouseEvent = cast js.Browser.document.createEvent("MouseEvents");
									// ev.initMouseEvent("mousedown", true, true, js.Browser.window, 0, 5, 5, 5, 5, false, false, false, false, 0, null);
									// var ok = select.dispatchEvent(ev);

								case F_Point:
							}
						});
					}
				}
			}
		}

		// Position panel
		var wh = js.Browser.window.innerHeight;
		var h = jPanel.outerHeight();
		jPanel.css("top", Std.int(wh*0.5 - h*0.5)+"px");


		JsTools.parseComponents(jPanel);
		renderLink();
	}
}