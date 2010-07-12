import flash.events.Event;
import flash.events.OutputProgressEvent;
import flash.filesystem.File;
import flash.filesystem.FileStream;

import mx.controls.Alert;

private var active_title:String = "This File";

private function create_new_file(title:String):void {
	
}

// this method writes text to a new file or updates a file
private function write_to_file():void {
	var file_text:String = main_text_area.text;
	var file_title:String = "New item";
	var path_to_file:String = "app_storage:/" + title + ".txt";
	var file_name:String = title + ".txt";
	var this_file:File = File.desktopDirectory.resolvePath(active_title + ".txt");
	var fs:FileStream = new FileStream();
	fs.open(this_file, FileMode.WRITE);
	fs.addEventListener(OutputProgressEvent.OUTPUT_PROGRESS, file_written_alert);
	fs.writeUTFBytes(file_text);
	fs.close();
}

// need to figure out how to capture file written event from write_to_file
// this is just a stand-in until I get that
private function file_written_alert(event:OutputProgressEvent):void {
	Alert.show("File written from filestream output progress", "Write to file");
}

// this method reads text from a file with a file matching the active_title 
private function read_from_file():void {
	//Alert.show("Reading from file", "Reading");
	var f:File = File.desktopDirectory.resolvePath(active_title + ".txt");
	var fs:FileStream = new FileStream();
	fs.open(f, FileMode.READ);
	var txt:String = fs.readUTFBytes(fs.bytesAvailable);
	fs.close();
	main_text_area.text = txt;
	//Alert.show(txt, "This is the file text");
}

// this method searches titles and text for keywords
// pretty important to figure out a good way to make this
// method nice and snappy; tied to onkeypress or onchange event
private function search():void {
	
}

// this method is called when a file is written; it may display some sort of
// notification to show that the current file has been saved
private function show_file_written(event:Event):void {
	
}

// word count for the current item
private function word_count():void {
	
}

// toggle word count display (maybe have a distraction-free, full-screen mode?
private function toggle_word_count():void {
	
}