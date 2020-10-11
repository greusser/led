package exporter;

import led.Json;

class Exporter {
	var log : dn.Log;
	var p : led.Project;
	var projectPath : dn.FilePath;
	var outputPath : Null<dn.FilePath>;
	var outputFiles : Array<{ path:String, bytes:haxe.io.Bytes }>;

	private function new() {
		log = new dn.Log(500);
		log.tagColors.set("level","#ffcc00");
		log.tagColors.set("layer","#46b8ff");
		log.tagColors.set("tileset","#b1ff56");
	}

	public final function run(p:led.Project, projectFilePath:String) {
		this.p = p;
		projectPath = dn.FilePath.fromFile(projectFilePath);
		outputFiles = [];

		if( outputPath==null ) {
			outputPath = projectPath.clone();
			outputPath.fileWithExt = null;
		}

		log.general("Init...");
		init();

		log.general("Converting project ("+Type.getClassName(Type.getClass(this))+")...");
		log.fileOp('  Project: ${projectPath.full}');
		log.fileOp('  Output: ${outputPath.full}');
		convert();

		log.fileOp('Writing ${outputFiles.length} output file(s)...');
		writeFiles();

		log.general('Done.');

		// Display log
		#if !debug
		if( log.containsAnyCriticalEntry() )
		#end
			new ui.modal.dialog.LogPrint(log);
	}

	function addOuputFile(path:String, bytes:haxe.io.Bytes) {
		outputFiles.push({
			path: path,
			bytes: bytes
		});
	}

	function init() {}
	function convert() {}
	function writeFiles() {
		for(f in outputFiles) {
			log.fileOp('  ${f.path}...');
			JsTools.writeFileBytes(f.path, f.bytes);
		}
	}

	public function setOutputPath(dirPath:String, removeAllFilesInDir:Bool) {
		log.fileOp("Changing output: "+outputPath.full);
		outputPath = dn.FilePath.fromDir(dirPath);


		log.fileOp("  Initializing dir...");
		JsTools.createDir(outputPath.full);
		if( removeAllFilesInDir )
			JsTools.emptyDir(outputPath.full);
	}

	function remapRelativePath(relPath:String) : String {
		var fp = dn.FilePath.fromFile(relPath);
		if( fp.hasDriveLetter() )
			return relPath; // it's actually an absolute path

		var abs = dn.FilePath.fromFile( projectPath.directory + "/" + relPath );
		return abs.makeRelativeTo( outputPath.full ).full;
	}

}
