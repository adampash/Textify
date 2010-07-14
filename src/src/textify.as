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
private var search_focus:Boolean = false;		// this boolean indicates whether search has focus
private var title_array:Array = new Array();	// this array contains only note titles
private var rich_array:Array = new Array(); 	// this array contains note title, text, and modified date
private var back_pressed:Boolean = false;

private function create_new_file(title:String):void {
	
}

// this method writes text to a new file or updates a file
private function write_to_file(title:String, file_text:String):void {
	var file_text:String = main_text_area.text;
	var file_title:String = "New item";
	var path_to_file:String = "app_storage:/" + title + ".txt";
	var file_name:String = title + ".txt";
	active_title = title;
	var this_file:File = File.desktopDirectory.resolvePath("Notes/" + file_name);
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
	active_title = title;
	word_count();
}

// this method deletes the currently active file
private function delete_note():void {
	Alert.show('Delete the note named "' + active_title + '"?', "Note delete");
	// need to finish this functionality
}

// this method searches titles and text for keywords
// pretty important to figure out a good way to make this
// method nice and snappy; tied to onkeypress or onchange event
private function search():void {
	var query:String = search_box.text.toLowerCase();
	//note_list.selectedIndex = title_array.indexOf(query); 
	var this_array:Array = title_array.filter(check_indexOf_query);
	note_list.dataProvider = new ArrayList(this_array);
	trace (this_array);
	// this block selects the first matching title name if the query
	// string matches the beginning of the title; the loop breaks as soon
	// as a match is found
	if (query.length > 0 && this_array.length != 0) {
		for (var i:uint = 0; i < this_array.length; i++) {
			if (this_array[i].toString().toLowerCase().indexOf(query) == 0) {
				note_list.selectedIndex = -1; // for some reason I have to set the index to -1 (nothing selected) or reselecting an already selected index will toggle its selection; annoying!
				note_list.selectedIndex = i;	
				search_box.text = note_list.selectedItem;
				search_box.selectRange(query.length, search_box.text.length);
				note_list.selectedIndex = i;
				break;
			}
		}		
	}
	
/*	if (!back_pressed && this_array.length != 0 && query.length > 0 && note_list.dataProvider.getItemAt(0).toLowerCase().indexOf(query) == 0) {
		note_list.selectedIndex = 0;
		search_box.text = note_list.selectedItem;
		search_box.selectRange(query.length, search_box.text.length);
	}
*/
}

// this function runs on each item in the note_list array to check that if it matches the query
private function check_indexOf_query(element:*, index:int, arr:Array):Boolean {
	return (element.toLowerCase().indexOf(search_box.text.toLowerCase()) != -1);
}

// the following two functions select next and previous search results in the note list display
private function select_next_note():void {
	if (note_list.selectedIndex != (note_list.dataProvider.length - 1)) {
		note_list.selectedIndex += 1;
		search_box.text = note_list.selectedItem;
	}
	search_box.selectAll();
}

private function select_previous_note():void {
	if (note_list.selectedIndex != 0) {
		note_list.selectedIndex -= 1;
		search_box.text = note_list.selectedItem;
	}
	search_box.selectAll();
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
// pulled this handy function from: http://www.actionscript.org/forums/archive/index.php3/t-100926.html
private function word_count():void {
	var lInputStr:String = main_text_area.text;
	var lTotLines:Array = lInputStr.split("\r");
	var WC:int = 0;
	for(var j:int=0;j<lTotLines.length;j++)
	{
		var lTotWords:Array=lTotLines[j].split(" ");
		for(var i:int=0;i<lTotWords.length;i++){
			if(lTotWords[i]!=""){
				WC++;
			}
		}
	}
	note_word_count.text = WC.toString() + " words";
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


// this method runs when the applicaiton creation event is complete;
// it adds the event listener for keyboard shortcuts 
// and scans the default notes folder for .txt files
// and creates arrays based on the files within
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
		if (file_list[i].name.indexOf('.txt') == -1) {
			continue;
		}
		title_array.push(file_list[i].name.split('.txt')[0]);
		//title_list.push(file_list[i].name.split('.txt')[0]);
		
		var title:String = file_list[i].name.split('.txt')[0];
		var f:File = File.desktopDirectory.resolvePath("Notes/" + file_list[i].name);
		var date:Date = f.modificationDate;
		var sort_date:Number = date.getTime();
		var fs:FileStream = new FileStream();
		fs.open(f, FileMode.READ);
		var txt:String = fs.readUTFBytes(fs.bytesAvailable);
		fs.close();
		rich_list.addItem({"title":title, "text":txt, "mod_date":date, "sort_date":sort_date});
	}
	rich_array = rich_list.toArray();
	rich_array = rich_array.sortOn("sort_date", Array.DESCENDING);
	title_array = [];
	for (var k:uint = 0; k < rich_array.length; k++) {
		title_array.push(rich_array[k].title);
		trace (rich_array[k].title);
	}
	var convert_list:ArrayList = new ArrayList(title_array);
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
	if (kc == 8 && event.ctrlKey) {
		delete_note();
	}
	if (kc == 27) {
		search_box.text = '';
		search_box.setFocus();
		// clear main_text_area
		search();
	}
	// implent Cmd/Ctrl+Del to delete a note (with confirmation
	if (search_focus == true) {
		if (kc == 40) {						// down arrow
			event.preventDefault();
			select_next_note();
		}
		else if (kc == 38) {				// up arrow
			event.preventDefault();
			select_previous_note();					
		}
		if (kc == 8) {
			back_pressed = true;
			if (search_box.selectionActivePosition != search_box.selectionAnchorPosition) {
				search_box.text = search_box.text.slice(0, search_box.selectionAnchorPosition);
				search_box.selectRange(search_box.text.length, search_box.text.length);
			}
		}
		else {
			back_pressed = false;
		}
	}
}