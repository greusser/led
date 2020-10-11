typedef SelectionBounds = { top:Int, left:Int, right:Int, bottom:Int }

class GenericLevelElementGroup {
	var editor(get,never): Editor; inline function get_editor() return Editor.ME;

	var renderWrapper : h2d.Object;
	var ghost : h2d.Graphics;
	var selectRender : h2d.Graphics;
	var arrow : h2d.Graphics;
	var pointLinks : h2d.Graphics;
	var elements : Array< Null<GenericLevelElement> > = [];
	var bounds(get,never) : SelectionBounds;
	var _cachedBounds : SelectionBounds;

	var invalidatedSelectRender = true;

	var originalRects : Array< { leftPx:Int, rightPx:Int, topPx:Int, bottomPx:Int } > = [];

	public function new(?elems:Array<GenericLevelElement>) {
		if( elems!=null )
			elements = elems.copy();

		renderWrapper = new h2d.Object();
		editor.levelRender.root.add(renderWrapper, Const.DP_UI);

		ghost = new h2d.Graphics(renderWrapper);

		arrow = new h2d.Graphics(renderWrapper);
		pointLinks = new h2d.Graphics(renderWrapper);
		selectRender = new h2d.Graphics(renderWrapper);
		selectRender.filter = new h2d.filter.Group([
			new dn.heaps.filter.PixelOutline(0xffcc00),
			new dn.heaps.filter.PixelOutline(0x0),
		]);
		invalidateBounds();
	}

	public function clear() {
		elements = [];
		originalRects = [];
		clearGhost();
		invalidateBounds();
		invalidateSelectRender();
	}

	public function dispose() {
		renderWrapper.remove();
		originalRects = null;
		_cachedBounds = null;
		elements = null;
	}

	public inline function isEmpty() return elements.length==0 && originalRects.length==0;
	public inline function selectedElementsCount() return elements.length;
	public inline function allElements() return elements;
	public inline function getElement(idx:Int) return elements[idx];

	public function add(ge:GenericLevelElement) {
		for(e in elements)
			if( ge.equals(e) )
				return false;
		elements.push(ge);
		invalidateBounds();
		invalidateSelectRender();
		return true;
	}

	public function addSelectionRect(l,r,t,b) {
		originalRects.push({
			leftPx: M.imax(l, 0),
			rightPx: M.imin(r, editor.curLevel.pxWid),
			topPx: M.imax(t, 0),
			bottomPx: M.imin(b, editor.curLevel.pxHei),
		});
		invalidateBounds();
		invalidateSelectRender();
	}

	public function getSelectedLayerInstances() {
		var map = new Map();
		for(ge in elements)
			switch ge {
				case GridCell(li, _), Entity(li, _), PointField(li, _):
					map.set(li,li);
			}

		var lis = [];
		for(li in map)
			lis.push(li);
		return lis;
	}

	inline function invalidateSelectRender()  invalidatedSelectRender = true;
	inline function invalidateBounds()  _cachedBounds = null;

	function get_bounds() {
		if( _cachedBounds==null ) {
			if( elements.length==0 )
				_cachedBounds = { top:0, left:0, right:0, bottom:0 }
			else {
				_cachedBounds = {
					top : Const.INFINITE,
					left : Const.INFINITE,
					right : -Const.INFINITE,
					bottom : -Const.INFINITE,
				}

				for(e in elements) {
					var x = switch e {
						case GridCell(li, cx, cy): li.pxOffsetX + cx*li.def.gridSize;
						case Entity(li, ei): li.pxOffsetX + ei.x;
						case PointField(li, ei, fi, arrayIdx):
							var pt = fi.getPointGrid(arrayIdx);
							if( pt!=null )
								li.pxOffsetX + pt.cx*li.def.gridSize;
							else 0; // HACK should not happen? Need checks
					}
					var y = switch e {
						case GridCell(li, cx, cy): li.pxOffsetY + cy*li.def.gridSize;
						case Entity(li, ei): li.pxOffsetY +  ei.y;
						case PointField(li, ei, fi, arrayIdx):
							var pt = fi.getPointGrid(arrayIdx);
							if( pt!=null )
								li.pxOffsetY + pt.cy*li.def.gridSize;
							else 0; // HACK should not happen? Need checks
					}
					_cachedBounds.top = M.imin( _cachedBounds.top, y );
					_cachedBounds.bottom = M.imax( _cachedBounds.bottom, y );
					_cachedBounds.left = M.imin( _cachedBounds.left, x );
					_cachedBounds.right = M.imax( _cachedBounds.right, x );

					for(r in originalRects) {
						_cachedBounds.top = M.imin( _cachedBounds.top, r.topPx );
						_cachedBounds.bottom = M.imax( _cachedBounds.bottom, r.bottomPx );
						_cachedBounds.left = M.imin( _cachedBounds.left, r.leftPx );
						_cachedBounds.right = M.imax( _cachedBounds.right, r.rightPx );
					}

				}
			}
		}
		return _cachedBounds;
	}

	function clearGhost() {
		pointLinks.clear();
		pointLinks.visible = false;

		arrow.clear();
		arrow.visible = false;

		ghost.visible = false;
		ghost.clear();
		ghost.removeChildren();
	}

	function renderSelection() {
		selectRender.clear();
		selectRender.visible = true;
		var c = 0xffcc00;
		var a = 0.3;

		for(r in originalRects) {
			selectRender.beginFill(0x8ab7ff, a);
			selectRender.drawRect(r.leftPx, r.topPx, r.rightPx-r.leftPx, r.bottomPx-r.topPx);
		}

		for(ge in elements) {
			switch ge {
				case null:
				case GridCell(li, cx, cy):
					if( li.hasAnyGridValue(cx,cy) )
						selectRender.beginFill(c, a);
					else
						selectRender.beginFill(0x8ab7ff, a*0.6);
					selectRender.drawRect(
						li.pxOffsetX + cx*li.def.gridSize,
						li.pxOffsetY + cy*li.def.gridSize,
						li.def.gridSize,
						li.def.gridSize
					);

				case Entity(li, ei):
					selectRender.beginFill(c, a);
					selectRender.drawRect(
						li.pxOffsetX + ei.x - ei.def.width * ei.def.pivotX,
						li.pxOffsetY + ei.y - ei.def.height * ei.def.pivotY,
						ei.def.width,
						ei.def.height
					);

				case PointField(li, ei, fi, arrayIdx):
					selectRender.beginFill(c, a);
					var pt = fi.getPointGrid(arrayIdx);
					if( pt!=null )
						selectRender.drawCircle(
							li.pxOffsetX + (pt.cx+0.5)*li.def.gridSize,
							li.pxOffsetY + (pt.cy+0.5)*li.def.gridSize,
							li.def.gridSize*0.4
						);
			}
		}
	}

	function renderGhost() {
		clearGhost();

		for(ge in elements) {
			switch ge {
				case null:

				case GridCell(li, cx, cy):
					if( li.hasAnyGridValue(cx,cy) ) // TODO render empty cells
						switch li.def.type {
							case IntGrid:
								ghost.lineStyle();
								ghost.beginFill( li.getIntGridColorAt(cx,cy) );
								ghost.drawRect(
									li.pxOffsetX + cx*li.def.gridSize - bounds.left,
									li.pxOffsetY + cy*li.def.gridSize - bounds.top,
									li.def.gridSize,
									li.def.gridSize
								);
								ghost.endFill();

							case Tiles:
								var tid = li.getGridTile(cx,cy);
								var td = editor.project.defs.getTilesetDef( li.def.tilesetDefUid );
								var bmp = new h2d.Bitmap( td.getTile(tid), ghost );
								bmp.x = li.pxOffsetX + cx*li.def.gridSize - bounds.left;
								bmp.y = li.pxOffsetY + cy*li.def.gridSize - bounds.top;

							case Entities:
							case AutoLayer:
						}

				case Entity(li, ei):
					var e = display.LevelRender.createEntityRender(ei);
					ghost.addChild(e);
					e.alpha = 0.5;
					e.x = li.pxOffsetX + ei.x - bounds.left;
					e.y = li.pxOffsetY + ei.y - bounds.top;

				case PointField(li, ei, fi, arrayIdx):
					var pt = fi.getPointGrid(arrayIdx);
					if( pt!=null ) {
						var x = li.pxOffsetX + (pt.cx+0.5)*li.def.gridSize - bounds.left;
						var y = li.pxOffsetY + (pt.cy+0.5)*li.def.gridSize - bounds.top;
						ghost.lineStyle(1, ei.getSmartColor(false));
						ghost.drawCircle(x, y, li.def.gridSize*0.5);

						ghost.lineStyle();
						ghost.beginFill(ei.getSmartColor(false) );
						ghost.drawCircle(x, y, li.def.gridSize*0.3);
						ghost.endFill();
					}
			}
		}

		ghost.endFill();
		for(r in originalRects) {
			ghost.lineStyle(1,0xffcc00,0.5);
			ghost.drawRect(r.leftPx-bounds.left, r.topPx-bounds.top, r.rightPx-r.leftPx, r.bottomPx-r.topPx);
		}

		return ghost;
	}

	function getDeltaX(origin:MouseCoords, now:MouseCoords) {
		return snapToGrid()
			? ( now.cx - origin.cx ) * getSmartSnapGrid()
			: now.levelX - origin.levelX;
	}

	function getDeltaY(origin:MouseCoords, now:MouseCoords) {
		return snapToGrid()
			? ( now.cy - origin.cy ) * getSmartSnapGrid()
			: now.levelY - origin.levelY;
	}

	public function getSmartRelativeLayerInstance() : Null<led.inst.LayerInstance> {
		var l : led.inst.LayerInstance = null;
		for(ge in elements)
			switch ge {
				case null:

				case GridCell(li, _), Entity(li, _), PointField(li, _):
					if( l==null || li.def.gridSize>l.def.gridSize )
						l = li;
			}
		return l;
	}

	inline function getSmartSnapGrid() {
		var li = getSmartRelativeLayerInstance();
		return li==null ? 1 : li.def.gridSize;
	}

	public function hasIncompatibleGridSizes() {
		var grid = getSmartSnapGrid();
		for( ge in elements )
			switch ge {
			case null:
			case GridCell(li, _), Entity(li, _), PointField(li, _):
				if( li.def.gridSize<grid && grid % li.def.gridSize != 0 )
					return true;
			}

		return false;
	}

	function isEntitySelected(e:led.inst.EntityInstance) {
		for( ge in elements)
			switch ge {
				case Entity(li, ei):
					if( ei==e )
						return true;

				case _:
			}

		return false;
	}

	function isFieldValueSelected(f:led.inst.FieldInstance, idx:Int) {
		return getFieldValueSelectionIdx(f,idx) >= 0;
	}

	function getFieldValueSelectionIdx(f:led.inst.FieldInstance, idx:Int) : Int {
		for( i in 0...elements.length )
			switch elements[i] {
				case PointField(li, ei, fi, arrayIdx):
					if( fi==f && arrayIdx==idx )
						return i;

				case _:
			}

		return -1;
	}



	inline function levelToGhostX(v:Float) {
		return v - bounds.left + ghost.x;
	}

	inline function levelToGhostY(v:Float) {
		return v - bounds.top + ghost.y;
	}

	public function onMoveStart() {
		renderGhost();
	}

	public function onMoveEnd() {
		clearGhost();
		arrow.clear();
		arrow.visible = false;
	}

	public function showGhost(origin:MouseCoords, now:MouseCoords, isCopy:Bool) {
		var rel = getSmartRelativeLayerInstance();
		origin = origin.cloneRelativeToLayer(rel);
		now = now.cloneRelativeToLayer(rel);

		selectRender.visible = false;

		var offX = bounds.left - origin.levelX;
		var offY = bounds.top - origin.levelY;

		ghost.visible = true;
		ghost.x = offX + origin.levelX + getDeltaX(origin,now);
		ghost.y = offY + origin.levelY + getDeltaY(origin,now);


		// Movement arrow
		var onlyMovingPoints = true;
		for(ge in elements)
			if( !ge.match(PointField(_)) ) {
				onlyMovingPoints = false;
				break;
			}
		if( onlyMovingPoints || now.cx==origin.cx && now.cy==origin.cy )
			arrow.visible = false;
		else {
			var grid = getSmartSnapGrid();
			var fx = rel.pxOffsetX + (origin.cx+0.5) * grid;
			var fy = rel.pxOffsetY + (origin.cy+0.5) * grid;
			var tx = rel.pxOffsetX + (now.cx+0.5) * grid;
			var ty = rel.pxOffsetY + (now.cy+0.5) * grid;

			var a = Math.atan2(ty-fy, tx-fx);
			var size = 6;

			// Main line
			var c = isCopy ? 0xffcc00 : 0xffffff;
			arrow.clear();
			arrow.visible = true;
			arrow.lineStyle(1, c);
			if( !isCopy ) {
				arrow.moveTo(fx,fy);
				arrow.lineTo(tx,ty);
			}
			else {
				var d = 2;
				arrow.moveTo( fx+Math.cos(a+M.PIHALF)*d*0.5, fy+Math.sin(a+M.PIHALF)*d*0.5 );
				arrow.lineTo( tx+Math.cos(a+M.PIHALF)*d*0.5, ty+Math.sin(a+M.PIHALF)*d*0.5 );

				arrow.moveTo( fx+Math.cos(a-M.PIHALF)*d*0.5, fy+Math.sin(a-M.PIHALF)*d*0.5 );
				arrow.lineTo( tx+Math.cos(a-M.PIHALF)*d*0.5, ty+Math.sin(a-M.PIHALF)*d*0.5 );
			}

			// "Wings"
			arrow.lineStyle(2, c, 1);
			arrow.moveTo( tx, ty );
			arrow.lineTo( tx + Math.cos(a+M.PI*0.8)*size, ty + Math.sin(a+M.PI*0.8)*size );

			arrow.moveTo(tx,ty);
			arrow.lineTo( tx + Math.cos(a-M.PI*0.8)*size, ty + Math.sin(a-M.PI*0.8)*size );

			// Arrow peak fix
			arrow.beginFill(c);
			arrow.lineStyle();
			arrow.drawCircle(tx,ty,1,8);
			arrow.endFill();

		}


		// Render point links
		pointLinks.clear();
		pointLinks.visible = !isCopy;
		for(ge in elements)
			switch ge {
				case Entity(li,ei):
					for(fi in ei.getFieldInstancesOfType(F_Point)) {
						if( fi.def.editorDisplayMode!=PointPath && fi.def.editorDisplayMode!=PointStar )
							continue;

						// Links to Entity own field points
						for( i in 0...fi.getArrayLength() ) {
							if( i>0 && fi.def.editorDisplayMode==PointPath )
								continue;

							pointLinks.lineStyle(1,ei.getSmartColor(true));
							pointLinks.moveTo( levelToGhostX(ei.x), levelToGhostY(ei.y) );
							var pt = fi.getPointGrid(i);
							if( pt!=null )
								if( isFieldValueSelected(fi,i) ) {
									pointLinks.lineTo(
										levelToGhostX( li.pxOffsetX+(pt.cx+0.5)*li.def.gridSize ),
										levelToGhostY( li.pxOffsetY+(pt.cy+0.5)*li.def.gridSize )
									);
								}
								else
									pointLinks.lineTo(
										li.pxOffsetX+(pt.cx+0.5)*li.def.gridSize,
										li.pxOffsetY+(pt.cy+0.5)*li.def.gridSize
									);
						}
					}

				case PointField(li, ei, fi, arrayIdx):
					pointLinks.lineStyle(1,ei.getSmartColor(true));
					var pt = fi.getPointGrid(arrayIdx);
					if( pt!=null ) {
						var x = levelToGhostX( li.pxOffsetX+(pt.cx+0.5)*li.def.gridSize );
						var y = levelToGhostY( li.pxOffsetY+(pt.cy+0.5)*li.def.gridSize );

						// Link to entity
						if( fi.def.editorDisplayMode==PointStar || arrayIdx==0 ) {
							pointLinks.moveTo(x,y);
							if( !isEntitySelected(ei) )
								pointLinks.lineTo(ei.x, ei.y);
							else
								pointLinks.lineTo( levelToGhostX(ei.x), levelToGhostY(ei.y) );
						}

						if( fi.def.editorDisplayMode==PointPath ) {
							// Link to previous point in path
							if( arrayIdx>0 ) {
								var prev = fi.getPointGrid(arrayIdx-1);
								if( prev!=null ) {
									pointLinks.moveTo(x,y);
									if( isFieldValueSelected(fi,arrayIdx-1) )
										pointLinks.lineTo(
											levelToGhostX( li.pxOffsetX+(prev.cx+0.5)*li.def.gridSize ),
											levelToGhostY( li.pxOffsetY+(prev.cy+0.5)*li.def.gridSize )
										);
									else
										pointLinks.lineTo(
											li.pxOffsetX+(prev.cx+0.5)*li.def.gridSize,
											li.pxOffsetY+(prev.cy+0.5)*li.def.gridSize
										);
								}
							}

							// Link to next point in path
							if( arrayIdx<fi.getArrayLength()-1 ) {
								var next = fi.getPointGrid(arrayIdx+1);
								if( next!=null ) {
									pointLinks.moveTo(x,y);
									if( isFieldValueSelected(fi,arrayIdx+1) )
										pointLinks.lineTo(
											levelToGhostX( li.pxOffsetX+(next.cx+0.5)*li.def.gridSize ),
											levelToGhostY( li.pxOffsetX+(next.cy+0.5)*li.def.gridSize )
										);
									else
										pointLinks.lineTo(
											li.pxOffsetX+(next.cx+0.5)*li.def.gridSize,
											li.pxOffsetY+(next.cy+0.5)*li.def.gridSize
										);
								}
							}
						}
					}

				case _:
			}
	}


	public function isOveringSelection(m:MouseCoords) {
		for(ge in elements) {
			switch ge {
				case GridCell(li, cx, cy):
					if( m.getLayerCx(li)==cx && m.getLayerCy(li)==cy )
						return true;

				case Entity(li, ei):
					if( ei.isOver(m.layerX, m.layerY) )
						return true;

				case PointField(li, ei, fi, arrayIdx):
					var pt = fi.getPointGrid(arrayIdx);
					if( pt!=null && m.getLayerCx(li)==pt.cx && m.getLayerCy(li)==pt.cy )
						return true;
			}
		}

		for(r in originalRects)
			if( m.levelX>=r.leftPx && m.levelX<=r.rightPx && m.levelY>=r.topPx && m.levelY<=r.bottomPx )
				return true;

		return false;
	}


	function snapToGrid() {
		return true;
	}


	public function moveSelecteds(origin:MouseCoords, to:MouseCoords, isCopy:Bool) : Array<led.inst.LayerInstance> {
		if( elements.length==0 )
			return [];

		var rel = getSmartRelativeLayerInstance();
		origin = origin.cloneRelativeToLayer(rel);
		to = to.cloneRelativeToLayer(rel);

		invalidateBounds();
		invalidateSelectRender();

		var postRemovals : Array< Void->Void > = [];
		var postInserts : Array< Void->Void > = [];
		var changedLayers : Map<led.inst.LayerInstance, led.inst.LayerInstance> = [];

		// Clear arrival to emulate "empty cell selection" mode
		if( originalRects.length>0 ) {
			for(r in originalRects) {
				r.leftPx += getDeltaX(origin,to);
				r.rightPx += getDeltaX(origin,to);
				r.topPx += getDeltaY(origin,to);
				r.bottomPx += getDeltaY(origin,to);
			}

			var layers = editor.singleLayerMode
				? [ editor.curLayerInstance ]
				: editor.curLevel.layerInstances;
			for(li in layers)
				if( editor.levelRender.isLayerVisible(li) && ( li.def.type==IntGrid || li.def.type==Tiles ) ) {
					for(r in originalRects) {
						for(cx in li.levelToLayerCx(r.leftPx)...li.levelToLayerCx(r.rightPx+1))
						for(cy in li.levelToLayerCy(r.topPx)...li.levelToLayerCy(r.bottomPx+1)) {
							if( li.def.type==IntGrid )
								postRemovals.push( li.removeIntGrid.bind(cx,cy) );

							if( li.def.type==Tiles )
								postRemovals.push( li.removeGridTile.bind(cx,cy) );
						}
					}
					changedLayers.set(li,li);
				}
		}

		// Prepare movement effects
		var moveGrid = getSmartSnapGrid();
		for( i in 0...elements.length ) {
			var ge = elements[i];
			switch ge {
				case null:

				case Entity(li, ei):
					var i = i;
					if( isCopy ) {
						ei = li.duplicateEntityInstance(ei);
						elements[i] = Entity(li,ei);
						if( ui.EntityInstanceEditor.isOpen() )
							ui.EntityInstanceEditor.openFor(ei);
					}
					ei.x += getDeltaX(origin, to);
					ei.y += getDeltaY(origin, to);
					changedLayers.set(li,li);

					// Out of bounds
					if( ei.x<li.pxOffsetX || ei.x>=li.pxOffsetX+li.cWid*li.def.gridSize
					|| ei.y<li.pxOffsetY || ei.y>=li.pxOffsetY+li.cHei*li.def.gridSize ) {
						li.removeEntityInstance(ei);
						elements[i] = null;

						// Unselect lost entity points
						for(fi in ei.fieldInstances)
						for(i in 0...fi.getArrayLength()) {
							var selIdx = getFieldValueSelectionIdx(fi,i);
							elements[selIdx] = null;
						}

						editor.ge.emit( EntityInstanceRemoved(ei) );
					}
					else
						editor.ge.emit( EntityInstanceChanged(ei) );

					// Remap points
					if( isCopy ) {
						var dcx = Std.int( getDeltaX(origin,to) / li.def.gridSize );
						var dcy = Std.int( getDeltaY(origin,to) / li.def.gridSize );

						for(fi in ei.getFieldInstancesOfType(F_Point))
						for( i in 0...fi.getArrayLength() ) {
							var pt = fi.getPointGrid(i);
							if( pt!=null ) {
								pt.cx+=dcx;
								pt.cy+=dcy;
								fi.parseValue(i, pt.cx+Const.POINT_SEPARATOR+pt.cy);
							}
						}
					}

				case GridCell(li, cx,cy):
					if( li.hasAnyGridValue(cx,cy) )
						switch li.def.type {
							case IntGrid:
								var v = li.getIntGrid(cx,cy);
								var gridRatio = Std.int( moveGrid / li.def.gridSize );
								var tcx = cx + (to.cx-origin.cx)*gridRatio;
								var tcy = cy + (to.cy-origin.cy)*gridRatio;
								if( !isCopy && li.hasIntGrid(cx,cy) )
									postRemovals.push( ()-> li.removeIntGrid(cx,cy) );
								postInserts.push( ()-> li.setIntGrid(tcx, tcy, v) );

								elements[i] = li.isValid(tcx,tcy) ? GridCell(li, tcx, tcy) : null; // update selection
								changedLayers.set(li,li);

							case Tiles:
								var v = li.getGridTile(cx,cy);
								var gridRatio = Std.int( moveGrid / li.def.gridSize );
								var tcx = cx + (to.cx-origin.cx)*gridRatio;
								var tcy = cy + (to.cy-origin.cy)*gridRatio;
								if( !isCopy && li.hasGridTile(cx,cy) )
									postRemovals.push( ()-> li.removeGridTile(cx,cy) );
								postInserts.push( ()-> li.setGridTile(tcx, tcy, v) );

								elements[i] = li.isValid(tcx,tcy) ? GridCell(li, tcx, tcy) : null; // update selection
								changedLayers.set(li,li);

							case Entities:
							case AutoLayer:
						}

				case PointField(li, ei, fi, arrayIdx):
					if( isCopy )
						elements[i] = null;
					else {
						var pt = fi.getPointGrid(arrayIdx);
						// Duplicate
						if( isCopy ) {
							fi.addArrayValue();
							var newIdx = fi.getArrayLength()-1;
							fi.parseValue( newIdx, fi.getPointStr(arrayIdx) );
							pt = fi.getPointGrid(newIdx);
							elements[i] = PointField(li,ei,fi,newIdx);
						}

						pt.cx += Std.int( getDeltaX(origin, to) / li.def.gridSize );
						pt.cy += Std.int( getDeltaY(origin, to) / li.def.gridSize );

						if( li.isValid(pt.cx,pt.cy) )
							fi.parseValue(arrayIdx, pt.cx+Const.POINT_SEPARATOR+pt.cy);
						else {
							// Out of bounds
							fi.removeArrayValue(arrayIdx);
							decrementAllFieldArrayIdxAbove(fi, arrayIdx);
							elements[i] = null;
						}
						editor.ge.emit( EntityInstanceChanged(ei) );

						changedLayers.set(li,li);
					}
			}
		}

		// Execute move
		for(cb in postRemovals) cb();
		for(cb in postInserts) cb();

		// Call refresh events
		var affectedLayers = [];
		for(li in changedLayers) {
			editor.ge.emit( LayerInstanceChanged );
			editor.levelRender.invalidateLayer(li);
			affectedLayers.push(li);
		}

		// Grabage collect "null" selections
		var i = 0;
		while( i<elements.length )
			if( elements[i]==null )
				elements.splice(i,1);
			else
				i++;

		return affectedLayers;
	}


	function decrementAllFieldArrayIdxAbove(f:led.inst.FieldInstance, above:Int) {
		for(i in 0...elements.length)
			switch elements[i] {
				case PointField(li, ei, fi, arrayIdx):
					if( fi==f && arrayIdx>=above )
						elements[i] = PointField(li,ei,fi,arrayIdx-1);

				case _:
			}
	}

	public function deleteSelecteds() {
		for(ge in elements)
			switch ge {
				case null:

				case GridCell(li, cx, cy):
					if( li.hasAnyGridValue(cx,cy) )
						switch li.def.type {
							case IntGrid: li.removeIntGrid(cx,cy);
							case Tiles: li.removeGridTile(cx,cy);
							case Entities:
							case AutoLayer:
						}

				case Entity(li, ei):
					li.removeEntityInstance(ei);

				case PointField(li, ei, fi, arrayIdx):
					fi.removeArrayValue(arrayIdx);
					decrementAllFieldArrayIdxAbove(fi, arrayIdx);
			}

		clear();
	}

	public function onPostUpdate() {
		if( invalidatedSelectRender ) {
			invalidatedSelectRender = false;
			renderSelection();
		}
	}
}