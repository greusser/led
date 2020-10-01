package led.def;

class AutoLayerRuleDef {
	#if heaps // Required to avoid doc generator to explore code too deeply

	public var uid(default,null) : Int;

	public var tileIds : Array<Int> = [];
	public var chance : Float = 1.0;
	public var size(default,null): Int;
	var pattern : Array<Int> = [];
	public var flipX = false;
	public var flipY = false;
	public var active = true;
	public var tileMode : led.LedTypes.AutoLayerRuleTileMode = Single;
	public var pivotX = 0.;
	public var pivotY = 0.;
	public var xModulo = 1;
	public var yModulo = 1;
	public var checker : led.LedTypes.AutoLayerRuleCheckerMode = None;

	var perlinActive = false;
	public var perlinSeed : Int;
	public var perlinScale : Float = 0.2;
	public var perlinOctaves = 2;
	var _perlin(get,null) : Null<hxd.Perlin>;

	public function new(uid, size=3) {
		if( !isValidSize(size) )
			throw 'Invalid rule size ${size}x$size';

		this.uid = uid;
		this.size = size;
		perlinSeed = Std.random(9999999);
		initPattern();
	}

	inline function isValidSize(size:Int) {
		return size>=1 && size<=Const.MAX_AUTO_PATTERN_SIZE && size%2!=0;
	}

	inline function get__perlin() {
		if( perlinSeed!=null && _perlin==null ) {
			_perlin = new hxd.Perlin();
			_perlin.normalize = true;
			_perlin.adjustScale(50, 1);
		}

		if( perlinSeed==null && _perlin!=null )
			_perlin = null;

		return _perlin;
	}

	public inline function hasPerlin() return perlinActive;

	public function setPerlin(active:Bool) {
		if( !active ) {
			perlinActive = false;
			_perlin = null;
		}
		else
			perlinActive = true;
	}

	public function isSymetricX() {
		for( cx in 0...Std.int(size*0.5) )
		for( cy in 0...size )
			if( pattern[coordId(cx,cy)] != pattern[coordId(size-1-cx,cy)] )
				return false;

		return true;
	}

	public function isSymetricY() {
		for( cx in 0...size )
		for( cy in 0...Std.int(size*0.5) )
			if( pattern[coordId(cx,cy)] != pattern[coordId(cx,size-1-cy)] )
				return false;

		return true;
	}

	public inline function get(cx,cy) {
		return pattern[ coordId(cx,cy) ];
	}

	public inline function set(cx,cy,v) {
		// clearOptim();
		return pattern[ coordId(cx,cy) ] = v;
	}

	function initPattern() {
		pattern = [];
		for(i in 0...size*size)
			pattern[i] = 0;
	}

	@:keep public function toString() {
		return 'Rule(${size}x$size):$pattern';
	}

	public function toJson() {
		tidy();

		return {
			uid: uid,
			active: active,
			size: size,
			tileIds: tileIds.copy(),
			chance: JsonTools.writeFloat(chance),
			pattern: pattern.copy(), // WARNING: could leak to undo/redo leaks if (one day) pattern contained objects
			flipX: flipX,
			flipY: flipY,
			xModulo: xModulo,
			yModulo: yModulo,
			checker: JsonTools.writeEnum(checker, false),
			tileMode: JsonTools.writeEnum(tileMode, false),
			pivotX: JsonTools.writeFloat(pivotX),
			pivotY: JsonTools.writeFloat(pivotY),

			perlinActive: perlinActive,
			perlinSeed: perlinSeed,
			perlinScale: JsonTools.writeFloat(perlinScale),
			perlinOctaves: perlinOctaves,
		}
	}

	public static function fromJson(jsonVersion:String, json:Dynamic) {
		var r = new AutoLayerRuleDef( json.uid, json.size );
		r.active = JsonTools.readBool(json.active, true);
		r.tileIds = json.tileIds;
		r.chance = JsonTools.readFloat(json.chance);
		r.pattern = json.pattern;
		r.flipX = JsonTools.readBool(json.flipX, false);
		r.flipY = JsonTools.readBool(json.flipY, false);
		r.checker = JsonTools.readEnum(led.LedTypes.AutoLayerRuleCheckerMode, json.checker, false, None);
		r.tileMode = JsonTools.readEnum(led.LedTypes.AutoLayerRuleTileMode, json.tileMode, false, Single);
		r.pivotX = JsonTools.readFloat(json.pivotX, 0);
		r.pivotY = JsonTools.readFloat(json.pivotY, 0);
		r.xModulo = JsonTools.readInt(json.xModulo, 1);
		r.yModulo = JsonTools.readInt(json.yModulo, 1);

		r.perlinActive = JsonTools.readBool(json.perlinActive, false);
		r.perlinScale = JsonTools.readFloat(json.perlinScale, 0.2);
		r.perlinOctaves = JsonTools.readInt(json.perlinOctaves, 2);
		r.perlinSeed = JsonTools.readInt(json.perlinSeed, Std.random(9999999));

		return r;
	}



	public function resize(newSize:Int) {
		if( !isValidSize(newSize) )
			throw 'Invalid rule size ${size}x$size';

		var oldSize = size;
		var oldPatt = pattern.copy();
		var pad = Std.int( dn.M.iabs(newSize-oldSize) / 2 );

		size = newSize;
		initPattern();
		if( newSize<oldSize ) {
			// Decrease
			for( cx in 0...newSize )
			for( cy in 0...newSize )
				pattern[cx + cy*newSize] = oldPatt[cx+pad + (cy+pad)*oldSize];
		}
		else {
			// Increase
			for( cx in 0...oldSize )
			for( cy in 0...oldSize )
				pattern[cx+pad + (cy+pad)*newSize] = oldPatt[cx + cy*oldSize];
		}
	}

	inline function coordId(cx,cy) return cx+cy*size;

	public function trim() {
		while( size>1 ) {
			var emptyBorder = true;
			for( cx in 0...size )
				if( pattern[coordId(cx,0)]!=0 || pattern[coordId(cx,size-1)]!=0 ) {
					emptyBorder = false;
					break;
				}
			for( cy in 0...size )
				if( pattern[coordId(0,cy)]!=0 || pattern[coordId(size-1,cy)]!=0 ) {
					emptyBorder = false;
					break;
				}

			if( emptyBorder )
				resize(size-2);
			else
				return false;
		}

		return true;
	}

	public function isEmpty() {
		for(v in pattern)
			if( v!=0 )
				return false;

		return tileIds.length==0;
	}

	public function matches(li:led.inst.LayerInstance, source:led.inst.LayerInstance, cx:Int, cy:Int, dirX=1, dirY=1) {
		if( tileIds.length==0 )
			return false;

		if( chance<=0 || chance<1 && dn.M.randSeedCoords(li.seed+uid, cx,cy, 100) >= chance*100 )
			return false;

		if( hasPerlin() && _perlin.perlin(perlinSeed, cx*perlinScale, cy*perlinScale, perlinOctaves) < 0 )
			return false;

		// Rule check
		var radius = Std.int( size/2 );
		for(px in 0...size)
		for(py in 0...size) {
			var coordId = px + py*size;
			if( pattern[coordId]==0 )
				continue;

			if( !source.isValid(cx+dirX*(px-radius), cy+dirY*(py-radius)) )
				return false;

			if( dn.M.iabs( pattern[coordId] ) == Const.AUTO_LAYER_ANYTHING+1 ) {
				// "Anything" checks
				if( pattern[coordId]>0 && !source.hasIntGrid(cx+dirX*(px-radius), cy+dirY*(py-radius)) )
					return false;

				if( pattern[coordId]<0 && source.hasIntGrid(cx+dirX*(px-radius), cy+dirY*(py-radius)) )
					return false;
			}
			else {
				// Specific value checks
				if( pattern[coordId]>0 && source.getIntGrid(cx+dirX*(px-radius), cy+dirY*(py-radius))!=pattern[coordId]-1 )
					return false;

				if( pattern[coordId]<0 && source.getIntGrid(cx+dirX*(px-radius), cy+dirY*(py-radius))==-pattern[coordId]-1 )
					return false;
			}
		}
		return true;
	}

	public function tidy() {
		var anyFix = false;

		if( flipX && isSymetricX() ) {
			flipX = false;
			anyFix = true;
		}

		if( flipY && isSymetricY() ) {
			flipY = false;
			anyFix = true;
		}

		if( xModulo==1 && yModulo==1 && checker!=None ) {
			checker = None;
			anyFix = true;
		}

		if( trim() )
			anyFix = true;

		return anyFix;
	}

	public function getRandomTileForCoord(seed:Int, cx:Int,cy:Int) : Int {
		return tileIds[ dn.M.randSeedCoords( seed, cx,cy, tileIds.length ) ];
	}

	#end
}