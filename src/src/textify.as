import com.adampash.components.renderers.ListItemRenderer;

import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.KeyboardEvent;
import flash.events.OutputProgressEvent;
import flash.filesystem.File;
import flash.filesystem.FileStream;

import mx.collections.ArrayList;
import mx.controls.Alert;
import mx.controls.List;

private var active_title:String = "This File";
private var search_focus:Boolean = false;
private var title_array:Array = new Array();

private function create_new_file(title:String):void {
	
}

// this method writes text to a new file or updates a file
private function write_to_file(title:String, file_text:String):void {
	var file_text:String = main_text_area.text;
	var file_title:String = "New item";
	var path_to_file:String = "app_storage:/" + title + ".txt";
	var file_name:String = title + ".txt";
	var this_file:File = File.desktopDirectory.resolvePath("Notes/" + active_title + ".txt");
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
private function read_from_file(title:String):void {
	//Alert.show("Reading from file", "Reading");
	var f:File = File.desktopDirectory.resolvePath("Notes/" + title + ".txt");
	if (f.exists) {
		var fs:FileStream = new FileStream();
		fs.open(f, FileMode.READ);
		var txt:String = fs.readUTFBytes(fs.bytesAvailable);
		fs.close();
		main_text_area.text = txt;
		main_text_area.setFocus();
	}
	else {
		write_to_file(title, '');
	}
	search_box.text = title;
	note_title.text = title;
	search_box.setStyle("color", "black");
	search_box.setStyle("fontStyle", "normal");
}

// this method searches titles and text for keywords
// pretty important to figure out a good way to make this
// method nice and snappy; tied to onkeypress or onchange event
private function search():void {
	var query:String = search_box.text;
	note_list.selectedIndex = title_array.indexOf(query); 
	var this_array:Array = title_array.filter(check_indexOf_query);
	//Alert.show(search_box.text, "Search string");
	//TextSearchEngine.findExact({key:search_box.text, textField:main_text_area.text});
	
}

// this function runs on each item in the note_list array to check that if it matches the query
private function check_indexOf_query(element:*, index:int, arr:Array):Boolean {
	return element.indexOf(search_box.text);
}

// the following two functions select next and previous search results in the note list display
private function select_next_note():void {
	note_list.selectedIndex += 1;
	search_box.text = note_list.selectedItem;
}

private function select_previous_note():void {
	if (note_list.selectedIndex != 0) {
		note_list.selectedIndex -= 1;
		search_box.text = note_list.selectedItem;
	}
}

// determine whether the search box identifies a new note or an existing note
// if new, create new note with current search box title
// if existing, load the existing note
private function activate_note_or_create_new():void {
	// clear whatever's currently in the main text area in preparation for the new note
	main_text_area.text = '';
	var new_note:Boolean = false;
	active_title = search_box.text;
	if (new_note) {
		// create a new note/file with the given title and no content
		write_to_file(active_title, '');
	}
	else {
		// if it's an existing file, read from the existing file
		read_from_file(search_box.text);
	}
	main_text_area.setFocus();
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

// sets search_focus to true (for keyboard shortcuts)
private function search_focused():void {
	search_focus = true;
	// if the search box containts the Search... text, this clears it when it's made active
	if (search_box.text == 'Search...') {
		search_box.text = '';
		search_box.setStyle("color", "black");
		search_box.setStyle("fontStyle", "normal");
	}
}

// sets search_focus to false (for keyboard shortcuts)
private function search_blurred():void {
	search_focus = false;
}

private function setup():void {
	// register callbacks for keyboard shortcuts
	stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	var directory:File = File.desktopDirectory.resolvePath("Notes/");
	var file_list:Array = directory.getDirectoryListing();
	trace (file_list);
	trace (file_list[2].name.split('.txt')[0]);
	// this if for testing the new ListItemRenderer
	var rich_list:ArrayList = new ArrayList();
	// end of ListItemRenderer test
	var title_list:Array = new Array();
	for (var i:uint = 0; i < file_list.length; i++) {
		trace(file_list[i].nativePath);
		if (file_list[i].name == ".DS_Store" || file_list[i].name == '') {
			continue;
		}
		title_array.push(file_list[i].name.split('.txt')[0]);
		title_list.push(file_list[i].name.split('.txt')[0]);
		
		var title:String = file_list[i].name.split('.txt')[0];
		var f:File = File.desktopDirectory.resolvePath("Notes/" + file_list[i].name);
		var fs:FileStream = new FileStream();
		fs.open(f, FileMode.READ);
		var txt:String = fs.readUTFBytes(fs.bytesAvailable);
		fs.close();
		rich_list.addItem({"title":title, "text":txt});
	}
	var convert_list:ArrayList = new ArrayList(title_list);
	note_list.dataProvider = convert_list;
	rich_note_list.dataProvider = rich_list;
}
	
// KEYBOARD SHORTCUTS GO HERE
private function onKeyDown(event:KeyboardEvent):void
{
	var kc:int = event.keyCode;
	if (kc == 76 && event.ctrlKey) {		// ctrl/cmd+l (Focus note search)
		event.preventDefault();
		search_box.setFocus();
		search_box.selectAll();
	}
	if (kc == 83 && event.ctrlKey) {		// ctrl/cmd+s (Save)
		event.preventDefault();
		write_to_file(active_title, main_text_area.text);
	}
	if (search_focus == true) {
		if (kc == 40) {						// down arrow
			event.preventDefault();
			select_next_note();
		}
		else if (kc == 38) {				// up arrow
			event.preventDefault();
			select_previous_note();					
		}
	}
}