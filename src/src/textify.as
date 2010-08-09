import com.adampash.components.loaders.URLURLLoader;
import com.adampash.components.renderers.ListItemRenderer;
import com.adobe.serialization.json.JSON;

import flash.data.SQLConnection;
import flash.data.SQLMode;
import flash.data.SQLResult;
import flash.data.SQLStatement;
import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.KeyboardEvent;
import flash.events.OutputProgressEvent;
import flash.events.SQLEvent;
import flash.filesystem.File;
import flash.filesystem.FileStream;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.utils.Timer;

import mx.collections.ArrayList;
import mx.controls.Alert;
import mx.controls.List;
import mx.events.CloseEvent;
import mx.messaging.channels.StreamingAMFChannel;
import mx.utils.Base64Encoder;

private var active_title:String = "";
private var active_key:String = "";				// carries the unique Simplenote key of the active note (how will this work for notes not on Simplenote?)
private var search_focus:Boolean = false;		// this boolean indicates whether search has focus
private var title_array:Array = new Array();	// this array contains only note titles
private var full_text_array:Array = new Array(); 	// this contains only note title and text
private var filtered_notes_array:Array = new Array(); 	// contains filtered versions of the title_array
private var rich_array:Array = new Array(); 	// this array contains note title, text, and modified date
private var db_array:Array = new Array();		// contains everything pulled from the database on any refresh_notes() SELECT
private var match_indexes:Array = [];	// contains all the absolute indexes of the matched items in the filtered list set
private var query_length:int = 0;				// 
private var explicit_query:String = ''; 		// contains the text the user has explicitly typed into the search box rather than what's been autocompleted
private var last_explicit_query:String = '';	// contains the previous query text; set from explicit_query
		

// this method writes text to a new file or updates a file
private function write_to_file(title:String, file_text:String):void {
	trace('write_to_file');
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
	trace ('write to file finished');
	var note_index:int = title_array.indexOf(title);
	refresh_note_arrays(note_index, title, file_text);
}

// this method rebuilds the array for new writes on existing notes
// called from both write_to_file and save_new_title
private function refresh_note_arrays(note_index:int, title:String, file_text:String):void {
	trace('refresh_note_arrays');
	title_array.splice(note_index, 1);
	title_array.unshift(title);
	full_text_array.splice(note_index, 1);
	full_text_array.unshift(title + " " + file_text);
}

// need to figure out how to capture file written event from write_to_file
// this is just a stand-in until I get that
private function file_written_alert(event:OutputProgressEvent):void {
	Alert.show("File written from filestream output progress", "Write to file");
}

// this method reads text from a file with a file matching the active_title 
private function read_from_file(title:String):void {
	trace('read_from_file');
	var f:File = File.desktopDirectory.resolvePath("Notes/" + title + ".txt");
	if (f.exists) {
		var fs:FileStream = new FileStream();
		fs.open(f, FileMode.READ);
		var txt:String = fs.readUTFBytes(fs.bytesAvailable);
		fs.close();
		main_text_area.text = txt;
		//main_text_area.setFocus();
	}
	else {
		if (title != '') {
			add_note_to_array();
			write_to_file(title, '');
			note_list.selectedIndex = 0;
			active_title = title;
			trace("Would normally create new note here; currently commented out.");
			//create_new_note();
		}
	}
	search_box.text = title;
	note_title.text = note_list.selectedItem;
	search_box.setStyle("color", "black");
	search_box.setStyle("fontStyle", "normal");
	active_title = title;
	last_save = main_text_area.text;
	word_count();
}

// currently not in use
private function display_note():void {
	set_title_and_text(note_list.selectedItem);
}

// this method deletes the currently active file
private function delete_note():void {
	trace('delete_note');
	var note:Object = note_list.selectedItem;
	var note_list_index:uint = note_list.selectedIndex;
	if (note_list.selectedIndex == -1) {
		trace('no note is selected');
		return; // do nothing if no note is selected
	}
	search_box.text = last_explicit_query;		// this and the next line are kludgy, but currently the workaround because event.preventDefault() isn't working for cmd/ctrl+delete
	search();									
	Alert.show('Delete the note named "' + note.title + '"?', "Note delete", Alert.YES|Alert.NO, this, confirm_delete, null, Alert.YES);
}

private function confirm_delete(event:CloseEvent):void {
	trace('confirm_delete');
	if (event.detail == Alert.YES) {
		var temp_sqls:SQLStatement = new SQLStatement();
		temp_sqls.sqlConnection = sqlc;
		temp_sqls.text = "UPDATE notes SET deleted = '1' WHERE key = '" + active_key + "';";
		temp_sqls.execute();
		var result:Array = temp_sqls.getResult().data;
		var url:String = "https://simple-note.appspot.com/api/delete?key=" + active_key;
		var request:URLRequest = new URLRequest(url);
		var url_loader:URLLoader = new URLLoader();
		url_loader.addEventListener(Event.COMPLETE, simplenote_marked_as_deleted);
		url_loader.load(request);
		refresh_notes();
		/*
		var file_name:String = search_box.text + ".txt"; 
		var file:File = File.desktopDirectory.resolvePath("Notes/" + file_name);
		if (file.exists) {
			trace ("Exists... deleting");
			file.deleteFile();
			remove_note_from_array();
			clear_search();
		}
		*/
	} 
}

private function simplenote_marked_as_deleted(e:Event):void {
	trace("Note with key " + e.target.data + " was marked as deleted on the Simplenote server.");
}

// the following two functions will add/remove notes to/from the array(s) as
// notes are created or deleted
private function add_note_to_array():void {
	// add a new item to the top of the list (goes to top because it's sorted by last modified)
	trace('add_note_to_array');
	trace("Note title: " + active_title);
	note_list.dataProvider.addItemAt(active_title, 0);
	title_array.unshift(active_title);
	full_text_array.unshift(active_title);
}

private function remove_note_from_array():void {
	// remove item from array
	trace('remove_note_from_array');
	var remove_index:uint = title_array.indexOf(active_title);
	title_array.splice(remove_index, 1);
	full_text_array.splice(remove_index, 1);
	note_title.text = '';
	search_box.text = '';
	main_text_area.text = '';
}

// this method searches titles and text for keywords
// pretty important to figure out a good way to make this
// method nice and snappy; tied to onkeypress or onchange event
private function search():void {
	trace('search');
	last_explicit_query = explicit_query;
	explicit_query = search_box.text;
	var query:String = search_box.text.toLowerCase();
	//note_list.selectedIndex = title_array.indexOf(query); 
	//filtered_notes_array = title_array.filter(filter_by_query);
	filtered_notes_array = [];
	var query_words:Array = search_box.text.toLowerCase().split(" ");
	match_indexes = [];
	for (var j:uint = 0; j < db_array.length; j++) {
		if (has_a_match(db_array[j].text, query_words)) {
			filtered_notes_array.push(db_array[j]);
			match_indexes.push(j);
		}
	}
	note_list.dataProvider = new ArrayList(filtered_notes_array);
	// this block selects the first matching title name if the query
	// string matches the beginning of the title; the loop breaks as soon
	// as a match is found
	if (query.length > 0 && filtered_notes_array.length != 0) {
		for (var i:uint = 0; i < filtered_notes_array.length; i++) {
			if (filtered_notes_array[i].title.toString().toLowerCase().indexOf(query) == 0) {
				note_list.selectedIndex = -1; // for some reason I have to set the index to -1 (nothing selected) or reselecting an already selected index will toggle its selection; annoying!
				note_list.selectedIndex = i;	
				search_box.text = search_box.text + note_list.selectedItem.title.substring(query.length);
				active_title = search_box.text;
				search_box.selectRange(query.length, search_box.text.length);
				note_list.selectedIndex = i;
				if (search_box.text.toLowerCase() != note_title.text.toLowerCase()) {
					//read_from_file(search_box.text);
					set_title_and_text(filtered_notes_array[i]);
				}
				// todo: highlight matching words inside note
				break;
			}
			else {
				main_text_area.text = '';
				note_title.text = '';
			}
		}		
	}
	else if (filtered_notes_array.length == 0) {
		note_title.text = '';
		main_text_area.text = '';
	}
	query_length = query.length;
}

// takes full text and sets title with first line, text area with remaining text
private function set_title_and_text(note:Object):void {
	if (note.text != null) {
		note_title.text = note.title;
		var note_text:String ='';
		if (note.text.split("\n").length > 1) {
			note_text = note.text.slice((note.text.indexOf("\n") + 1));
		}
		if (note_text.indexOf("\n") == 0) {
			note_text = note_text.slice((note_text.indexOf("\n") + 1));
		}
		main_text_area.text = note_text;
		active_key = note.key;
	}
	else {
		
	}
	word_count();
}

// this function runs on each item in the note_list array to check that if it matches the query
// if the item matches, it's returned
private function filter_by_query(element:*, index:int, arr:Array):Boolean {
	var words:Array = search_box.text.toLowerCase().split(" ");
	var match:Boolean = true;
	for (var i:uint = 0; i < words.length; i++) {
		if (element.toLowerCase().indexOf(words[i]) != -1) {
			match = true;
		}
		else {
			match = false;
			break;
		}
	}
	return match;
}

private function has_a_match(text:String, query_words:Array):Boolean {
	var match:Boolean = true;
	for (var i:uint = 0; i < query_words.length; i++) {
		if (text.toLowerCase().indexOf(query_words[i]) != -1) {
			//trace(query_words);
			match = true;
		}
		else {
			match = false;
			break;
		}
	}
	return match;
}

// the following two functions select next and previous search results in the note list display
private function select_next_note():void {
	if (note_list.selectedIndex != (note_list.dataProvider.length - 1)) {
		note_list.selectedIndex += 1;
		set_title_and_text(note_list.selectedItem);
		search_box.text = note_list.selectedItem.title;
		//read_from_file(search_box.text);
	}
	search_box.selectAll();
}

private function select_previous_note():void {
	if (note_list.selectedIndex != 0) {
		note_list.selectedIndex -= 1;
		set_title_and_text(note_list.selectedItem);
		//read_from_file(search_box.text);
		search_box.text = note_list.selectedItem.title;
	}
	search_box.selectAll();
}

// determine whether the search box identifies a new note or an existing note
// if new, create new note with current search box title
// if existing, load the existing note
private function activate_note_or_create_new():void {
	// clear whatever's currently in the main text area in preparation for the new note
	trace('activate_note_or_create_new');
	
	active_title = search_box.text;
	//read_from_file(search_box.text);
	if (note_list.selectedIndex == -1) {
		// insert new note in db
		var note:Object = new Object();
		note.text = search_box.text;
		trace(note.text);
		note.key = 'newnote_' + generateRandomString(7);
		var cur_date:String = current_date();
		note.modify = cur_date;
		trace(note.modify);
		note.utc_time = convert_to_UTC(note.modify);
		note.created = cur_date;
		note.deleted = 0;
		insert_new_note_in_db(note);
		// upload note with title to Simplenote
		var url:String = "https://simple-note.appspot.com/api/note?modify=" + note.modify + "&create=" + note.created;
		update_array[url] = note.key;
		var request:URLRequest = create_simplenote_request(url, note.text);
		var url_loader:URLURLLoader = new URLURLLoader();
		url_loader.addEventListener(Event.COMPLETE, new_note_pushed_to_simplenote);
		url_loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, url_handler_1)
		url_loader.load(request);

		//
		note_list.selectedIndex = 0;
		note_title.text = search_box.text;
		main_text_area.text = '';
	}
	else {
		trace('get in here');
		//set_title_and_text(full_text_array[match_indexes[note_list.selectedIndex]]);
	}
	main_text_area.setFocus();
}

// need to add simplenote key to newly created note after the new note goes to Simplenote
private function new_note_pushed_to_simplenote(e:Event):void {
	var temp_key:String = update_array[e.target.urlRequest.url];
	update_array[e.target.urlRequest.url] = '';
	var key:String = e.target.data;
	trace("Change note key from " + temp_key + " to " + key);
	var temp_sqls:SQLStatement = new SQLStatement();
	temp_sqls.sqlConnection = sqlc;
	temp_sqls.text = "UPDATE notes SET key = '" + key + "' WHERE key = '" + temp_key + "';";
	temp_sqls.execute();
	var result:Array = temp_sqls.getResult().data;
	if (note_list.selectedItem.key == temp_key) {
		active_key = key;
	}
	refresh_notes();
}

// timer that saves the active note every 5 seconds if it's changed; ideally we'll set up a better method 
// than a straight up timer for of regular saving
private var last_save:String = '';
private var save_timer:Timer = new Timer(5000);


// crude save function
private function save(event:TimerEvent):void {
	return; // disabling for now
	if (last_save != main_text_area.text && note_title.text != '') {
		var f:File = File.desktopDirectory.resolvePath("Notes/" + active_title + ".txt");
		if (f.exists) {
			trace("Saving via timer");
			write_to_file(active_title, main_text_area.text); // this should prob be a lot more robust
			last_save = main_text_area.text;
		}
	}
}

// saves the note locally, pushes save to Simplenote if network connection exists
private function save_note():void {
	var note:Object = note_list.selectedItem;
	note.text = note_title.text + "\n\n" + main_text_area.text;
	var modify:String = current_date();
	note.modify = modify;
	var utc_time:int = convert_to_UTC(note.modify);
	trace("The formatted mod date is: " + note.modify);
	var temp_sqls:SQLStatement = new SQLStatement();
	temp_sqls.sqlConnection = sqlc;
	temp_sqls.text = "UPDATE notes SET text = '" + escape(note.text) + "', unsynced_changes = '1', modify = '" + note.modify + "', utc_time = '" + utc_time + "' WHERE key = '" + note.key + "';";
	temp_sqls.execute();
	var result:Array = temp_sqls.getResult().data;
	refresh_notes();
	push_note(note);
	/*
	var text:String = note_title.text + "\n" + main_text_area.text;
	var key:String = update_array[e.target.urlRequest.url]['Note-Key'];
	var modify:String = update_array[e.target.urlRequest.url]['Note-Modifydate'];
	var utc_time:int = convert_to_UTC(modify);
	var created:String = update_array[e.target.urlRequest.url]['Note-Createdate'];
	var deleted_string:String = update_array[e.target.urlRequest.url]['Note-Deleted'].toString().toLowerCase(); 
	var deleted:int;
	if (deleted_string == 'true') {
		deleted = 1;
	}
	else {
		deleted = 0;
	}
	//var headers:Array = e.responseHeaders;
	trace("You're updating the note with: ");
	trace(text);
	var temp_sqls:SQLStatement = new SQLStatement();
	temp_sqls.sqlConnection = sqlc;
	temp_sqls.text = "UPDATE notes SET text = '" + text + "', modify = '" + modify + "', deleted = '" + deleted + "', utc_time = '" + utc_time + "' WHERE key = '" + key + "';";
	temp_sqls.execute();
	refresh_notes();
*/
}

// get current date formatted for Simplenote
private function current_date():String {
	var date:Date = new Date();
	var y:String, m:String, d:String, h:String, min:String, s:String;
	y = date.getUTCFullYear().toString();
	m = (date.getUTCMonth() + 1).toString();
	if (m.length == 1) m = "0" + m;
	d = date.getUTCDate().toString();
	if (d.length == 1) d = "0" + d;
	h = date.getUTCHours().toString();
	if (h.length == 1) h = "0" + h;
	min = date.getUTCMinutes().toString();
	if (min.length == 1) min = "0" + min;
	s = date.getUTCSeconds().toString();
	if (s.length == 1) s = "0" + s;
	var date_str:String = y + "-" + m + "-" + d + " " + h + ":" + min + ":" + s;
	return date_str;
}

// this method is called when a file is written; it may display some sort of
// notification to show that the current file has been saved
private function show_file_written(event:Event):void {
	
}

// shows an edit field when the user clicks the note_title label
private function edit_note_title():void {
	note_title_input.text = note_title.text;
	note_title_input.visible = true;
	note_title_input.setFocus();
}

private function save_new_title():void {
	trace('save_new_title');
	if (note_title.text != note_title_input.text) {
		var f:File = File.desktopDirectory.resolvePath("Notes/" + note_title.text + ".txt");
		var destination:File = File.desktopDirectory.resolvePath("Notes/" + note_title_input.text + ".txt");
		if (destination.exists) {
			trace("already exists");
			Alert.show("A note with this title already exists", "Ooops");
			// need to figure out how to make this work if the note is just a change in capitalization
			// since AIR won't move a file to a new file with the same name but diff. capitalization
			return;
		}
		else if (f.exists && note_title_input.text != '') {
			trace("moving/renaming file");
			f.moveTo(destination, true);
			var note_index:int = title_array.indexOf(note_title.text);
			refresh_note_arrays(note_index, note_title_input.text, main_text_area.text);
			note_title.text = note_title_input.text;
			trace('remove item at ' + note_list.selectedIndex.toString());
			if (note_list.selectedIndex != 0) {
				note_list.dataProvider.removeItemAt(note_list.selectedIndex);	
			}
			else {
				note_list.dataProvider.addItemAt(note_title_input.text, 0);
				note_list.dataProvider.removeItemAt(note_list.selectedIndex);
			}
			note_list.selectedIndex = 0;
			note_title_input.visible = false;
			note_title_input.text = '';
		}
	}
	else {
		trace('no changes to save');
	}
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

// toggle word count display (maybe have a distraction-free, full-screen mode?)
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

// this function is called when the user hits Escape or deletes a file
private function clear_search():void {
	search_box.text = '';
	search_box.setFocus();
	// clear main_text_area
	main_text_area.text = '';
	note_title.text = '';
	search();
}

// this method runs when the applicaiton creation event is complete;
// it adds the event listener for keyboard shortcuts 
// and scans the default notes folder for .txt files
// and creates arrays based on the files within
private function setup():void {
	// register callbacks for keyboard shortcuts
	stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	// scan file directory for notes
	open_database();
	// once database is open, first we need to display what we've got locally
	refresh_notes();
	// then we need to fetch index from Simplenote to see if anything needs updated
	get_simplenote_index();

	/* BELOW IS THE FILE-BASED METHOD; COMMENTING OUT WHILE I WORK ON THE SQLITE DATABASE METHOD
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
		rich_list.addItem({"title":title, "text":txt, "sort_date":sort_date});
	}
	rich_array = rich_list.toArray();
	rich_array = rich_array.sortOn("sort_date", Array.DESCENDING);
	title_array = [];
	full_text_array = [];
	for (var k:uint = 0; k < rich_array.length; k++) {
		title_array.push(rich_array[k].title); //+ rich_array[k].text);
		full_text_array.push(rich_array[k].title + " " + rich_array[k].text);
		trace (rich_array[k].title);
	}
	var convert_list:ArrayList = new ArrayList(title_array);
	*/
	//note_list.dataProvider = convert_list;
	// rich_note_list.dataProvider = rich_list;
	// set save timer
	save_timer.addEventListener(TimerEvent.TIMER, save);
	save_timer.start();
	trace("Setup is complete");
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
	else if (kc == 83 && event.ctrlKey) {		// ctrl/cmd+s (Save)
		event.preventDefault();
		//write_to_file(active_title, main_text_area.text);
		save_note();
	}
	else if (event.ctrlKey && kc == 8) {			// ctrl/cmd+delete (Delete)
		event.preventDefault();						// for some reason, preventDefault() doesn't work here, so implementing workaround in delete_note()
		delete_note();
	}
	else if (kc == 27) {							// Escape key
		clear_search();
	}
	else if (kc == 37 && event.commandKey) {		// Cmd+left; on Mac, the behavior wasn't going to EoL

	}
	else if (kc == 39 && event.commandKey) {		// Cmd+right
		
	}	
	// impelent Cmd/Ctrl+Del to delete a note (with confirmation
	else if (search_focus == true && !event.ctrlKey) {
		if (kc == 40) {						// down arrow
			event.preventDefault();
			select_next_note();
		}
		else if (kc == 38) {				// up arrow
			event.preventDefault();
			select_previous_note();					
		}
		else if (kc == 8) {						// delete/backspace
			trace("search focus delete");
			if (search_box.selectionActivePosition != search_box.selectionAnchorPosition) {
				search_box.text = search_box.text.slice(0, search_box.selectionAnchorPosition);
				search_box.selectRange(search_box.text.length, search_box.text.length);
				note_list.selectedIndex = -1;
				note_title.text = '';
				main_text_area.text = '';
			}
		}
	}
}


////// INTERACTING WITH SIMPLENOTE ///////
// storing encrypted data: http://livedocs.adobe.com/flex/3/html/help.html?content=EncryptedLocalStore_1.html

private var email:String = 'adam@lifehacker.com';

// function for logging into Simplenote; on success, AIR will
// store a cookie that it will send on subsequent requests
private function login_to_simplenote():void {
	trace('logging in');
	var request:URLRequest = create_simplenote_request("https://simple-note.appspot.com/api/login","email=" + email + "&password=testpass"); 
	request.manageCookies = true;
	var urlLoader:URLLoader = new URLLoader();
	urlLoader.dataFormat = "text";
	urlLoader.addEventListener(Event.COMPLETE, login_handler, false, 0, true);
	urlLoader.load(request);
}

// called when login_to_simplenote request completes
private function login_handler(e:Object):void
{
	// the response given from URL will be traced here
	trace('you got a response:');
	trace(e.target.data);
}

// creates a new note on the simplenote server with the new note's title
private function create_new_note():void {
	var request:URLRequest = create_simplenote_request('https://simple-note.appspot.com/api/note', active_title);
	var urlLoader:URLLoader = new URLLoader();
	urlLoader.dataFormat = "text";
	urlLoader.addEventListener(Event.COMPLETE, add_note_to_db, false, 0, true);
	urlLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, url_handler_1);
	urlLoader.load(request);
}

// handler called when create_new_note request completes
private function add_note_to_db(e:Object):void {
	trace('add this note key to the database');
	trace(e.target.data);
}

private function url_handler(e:Object):void {
	trace('url_handler');
	trace(e.target.data);
}

private function url_handler_1(e:Object):void {
	trace('http response status:');
	trace(e.target.data);
}

// this calls simplenote's index method, which returns a json object containing
// every note's deleted status, last modified date, and key
private function get_simplenote_index():void {
	var request:URLRequest = create_simplenote_request('https://simple-note.appspot.com/api/index', '');
	var urlLoader:URLLoader = new URLLoader();
	urlLoader.dataFormat = "text";
	urlLoader.addEventListener(Event.COMPLETE, sync_notes, false, 0, true);
	urlLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, url_handler_1)
	urlLoader.load(request);
}

// this handler is called when the get_simplenote_index method completes
// the data returned by simplenote contains a json object containing deletion 
// status, last modified date, and the key for each note
private function sync_notes(e:Object):void {
	// for these syncs, db can't be async opened, so closing and re-opening as synchronous
	
	trace('syncing notes');
	if (e.target.data != "") {
		var note_array:Array = (JSON.decode(e.target.data) as Array);
		var obj:Object = note_array[0];
		// loop through the array of notes
		for (var i:uint; i < note_array.length; i++) {
			// check to see if the note exists in the local database
			// if not, retrieve note from simplenote and add to/update database
			trace("Check if " + note_array[i].key + " exists");
			var temp_sqls:SQLStatement = new SQLStatement();
			temp_sqls.sqlConnection = sqlc;
			temp_sqls.text = "SELECT key, modify FROM notes WHERE key = '" + note_array[i].key + "'";
			temp_sqls.execute();
			var note_data:Array = temp_sqls.getResult().data;
			if (note_data == null) {
				trace("Note doesn't exist; inserting new value");
				var request:URLRequest = new URLRequest("https://simple-note.appspot.com/api/note?key=" + note_array[i].key);// + "&encode=base64"); 
				var urlLoader:URLURLLoader = new URLURLLoader();
				urlLoader.dataFormat = "text";
				urlLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, note_update_status);
				urlLoader.addEventListener(Event.COMPLETE, new_note_from_simplenote);
				urlLoader.load(request);
			}
			else {
				trace("Note already exists... check if modified");
				if (note_data[0].modify == note_array[i].modify) {
					trace('The note has not been modified');
				}
				else {
					trace('The note has been modified, needs to update the note with key ' + note_data[0].key);
					var request2:URLRequest = new URLRequest("https://simple-note.appspot.com/api/note?key=" + note_array[i].key);// + "&encode=base64"); 
					var urlLoader2:URLURLLoader = new URLURLLoader();
					urlLoader2.dataFormat = "text";
					urlLoader2.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, note_update_status);
					urlLoader2.addEventListener(Event.COMPLETE, pull_note);
					urlLoader2.load(request2);
				}
			}
		} 
		trace('Completed syncing notes');
	}
	// Once notes have finished syncing, need to update/display the updated index of notes
}

private function refresh_notes():void {
	trace("Refresh notes...");
	var temp_sqls:SQLStatement = new SQLStatement();
	temp_sqls.sqlConnection = sqlc;
	temp_sqls.text = "SELECT * FROM notes WHERE deleted = '0' ORDER BY utc_time DESC";
	temp_sqls.execute();
	db_array = temp_sqls.getResult().data;
	if (db_array != null) {
		var reactivate:int;
		for (var i:uint; i < db_array.length; i++) {
			db_array[i].text = unescape(db_array[i].text);
			db_array[i].title = db_array[i].text.split("\n")[0];
			if (db_array[i].key == active_key) {
				reactivate = i;
			}
		}
		//var convert_list:ArrayList = new ArrayList(title_array);
		note_list.dataProvider = new ArrayList(db_array);
		// will need to re-apply filter to this, but for now just try to select the currently active note
		trace("Reactivating list item " + reactivate);
		note_list.selectedIndex = -1;
		note_list.selectedIndex = reactivate;
	}
}

private function convert_to_UTC(date_str:String):int {
	var y_m_d:Array = date_str.split("-");
	var h_m_s:Array = y_m_d[2].split(" ")[1].split(":");
	//trace(y_m_d[0] + " " + (parseInt(y_m_d[1]) - 1).toString() + " " + y_m_d[2].split(" ")[0] + " " + h_m_s[0] + " " + h_m_s[1] + " " + h_m_s[2].split(".")[0] + " " + h_m_s[2].split(".")[1].slice(0, 3));
	var date:Date;
	
	// When notes are created on Simplenote, they timestamp to 6 decimal places. When you upload your own modify date, Simplenote discareds all fractions of a second
	// hence this if/else statement
	if (h_m_s[2].split(".").length > 1) {
		date = new Date(y_m_d[0], (parseInt(y_m_d[1]) - 1).toString(), y_m_d[2].split(" ")[0], h_m_s[0], h_m_s[1], h_m_s[2].split(".")[0], h_m_s[2].split(".")[1].slice(0, 3));
	}
	else {
		date = new Date(y_m_d[0], (parseInt(y_m_d[1]) - 1).toString(), y_m_d[2].split(" ")[0], h_m_s[0], h_m_s[1], h_m_s[2].split(".")[0]);
	}
	return date.getTime();
}

private var update_array:Array = new Array();
private function note_update_status(e:HTTPStatusEvent):void {
	trace(e.responseHeaders);
	var response_headers:Array = new Array();
	for (var i:uint; i < e.responseHeaders.length; i++) {
		response_headers[e.responseHeaders[i].name] = e.responseHeaders[i].value;
	}
	trace(response_headers);
	update_array[e.responseURL] = response_headers;
}

// 
private function new_note_from_simplenote(e:Event):void {
	var note:Object = parse_header_info(update_array[e.target.urlRequest.url]);
	note.text = e.target.data;
	//var headers:Array = e.responseHeaders;
	trace("You're creating the note with: ");
	trace(note.text);
	insert_new_note_in_db(note);
}

// parses response headers from Simplenote into a note object
// returns that note object
private function parse_header_info(headers:Array):Object {
	var note:Object = new Object();
	note.key = headers['Note-Key'];
	note.modify = headers['Note-Modifydate'];
	//trace(modify);
	note.utc_time = convert_to_UTC(note.modify);
	note.created = headers['Note-Createdate'];
	var deleted_string:String = headers['Note-Deleted'].toString().toLowerCase();
	//var note.deleted;
	if (deleted_string == 'true') {
		note.deleted = 1;
	}
	else {
		note.deleted = 0;
	}
	return note;
}

// this method inserts a new note in the db with key, text, modify, created, deleted, and utc_time set
private function insert_new_note_in_db(note:Object):void {
	var temp_sqls:SQLStatement = new SQLStatement();
	temp_sqls.sqlConnection = sqlc;
	temp_sqls.text = "INSERT INTO notes (key, text, modify, created, deleted, utc_time) VALUES('" + note.key + "', '" + escape(note.text) + "', '" + note.modify + "', '" + note.created + "', '" + note.deleted + "', '" + note.utc_time + "');";
	temp_sqls.execute();
	refresh_notes();
}

// update notes that already exist in the database with up-to-date content from Simplenote
// too much code duplication between this and new_note_from_simplenote method above
private function pull_note(e:Event):void {
	var note:Object = parse_header_info(update_array[e.target.urlRequest.url]);
	note.text = unescape(e.target.data);
	trace("You're updating the note with: ");
	trace(note.text);
	var temp_sqls:SQLStatement = new SQLStatement();
	temp_sqls.sqlConnection = sqlc;
	temp_sqls.text = "UPDATE notes SET text = '" + escape(note.text) + "', modify = '" + note.modify + "', deleted = '" + note.deleted + "', utc_time = '" + note.utc_time + "' WHERE key = '" + note.key + "';";
	temp_sqls.execute();
	refresh_notes();
}

// pushes local note updates to Simplenote
private function push_note(note:Object):void {
					 
	var url:String = "https://simple-note.appspot.com/api/note?key=" + note.key + "&modify=" + note.modify;
	var request:URLRequest = create_simplenote_request(url, note.text);
	var url_loader:URLLoader = new URLLoader();
	url_loader.addEventListener(Event.COMPLETE, note_pushed);
	url_loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, url_handler_1)
	url_loader.load(request);
}

private function note_pushed(e:Event):void {
	trace("note response came back: " + e.target.data);
}

// constructs the request to simplenote and encodes data when necessary
private function create_simplenote_request(url:String, data:String):URLRequest {
	var request:URLRequest = new URLRequest(url);
	if (data != '') {
		request.data = encode_text(data);	
	}
	request.method = URLRequestMethod.POST;
	return request;
}

// every POST request to Simplenote has to be base64-encoded
private function encode_text(text:String):String {
	var encoder:Base64Encoder = new Base64Encoder();
	encoder.encode(text);
	return encoder.toString();
}


//// DATABASE FUNCTIONS ////

private var sql_file:File;
private var sql_connection:SQLConnection;


// sqlc is a variable we need to define the connection to our database
private var sqlc:SQLConnection = new SQLConnection();
// sqlc is an SQLStatment which we need to execute our sql commands
private var sqls:SQLStatement = new SQLStatement();

// function we call at the begining when application has finished loading and bulding itself
private function open_database():void
{
	// first we need to set the file class for our database (in this example test.db). If the Database doesn't exists it will be created when we open it.
	var db:File = File.desktopDirectory.resolvePath("Notes/notes.db");
	// after we set the file for our database we need to open it with our SQLConnection.
	sqlc.open(db);
	sqls.sqlConnection = sqlc;
	sqls.text = "CREATE TABLE IF NOT EXISTS notes ( id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT UNIQUE, text TEXT, modify TEXT, created TEXT, unsynced_changes INTEGER DEFAULT '0', deleted INTEGER DEFAULT '0', utc_time INTEGER );";
	sqls.execute();
	// we need to set some event listeners so we know if we get an sql error, when the database is fully opened and to know when we recive a resault from an sql statment. The last one is uset to read data out of database.
	//sqlc.addEventListener(SQLEvent.OPEN, db_opened);
	//sqlc.addEventListener(SQLErrorEvent.ERROR, error);
	sqls.addEventListener(SQLErrorEvent.ERROR, error);
	sqls.addEventListener(SQLEvent.RESULT, statement_result);
	
}

// function to add item to our database
private function add_item_to_db(key:String, modify:String, title:String, text:String):void
{
	// in this sql statment we add item at the end of our table with values first_name.text in column first_name and last_name.text for column last_name
	if (sqls.executing) {
		trace('sleeping');
		setTimeout(add_item_to_db, 500, key, modify, title, text);
	} 
	else {
		sqls.text = "INSERT INTO notes (key, text, modify, created, deleted) VALUES('" + key + "', '" + modify + "', '" + escape(text) + "');";
		sqls.execute();
		//sqls.addEventListener(SQLEvent.RESULT, item_added);
	}
}

private function item_added(e:SQLEvent):void {
	trace('item added');
}

// method that gets called if we recive some resaults from our sql commands.
//this method would also get called for sql statments to insert item and to create table but in this case sqls.getResault().data would be null
private function statement_result(e:SQLEvent):void
{
	// with sqls.getResault().data we get the array of objects for each row out of our database
	var data:Array = sqls.getResult().data;
	trace('got a result');
	trace(data);
	//show_all();
	//trace('show all');
	// we pass the array of objects to our data provider to fill the datagrid
	//dp = new ArrayCollection(data);
}

private var sqls_all:SQLStatement = new SQLStatement();
private function show_all():void {
	sqls_all.sqlConnection = sqlc;
	sqls_all.text = "SELECT * FROM notes";
	sqls_all.addEventListener(SQLEvent.RESULT, show_all_result);
	sqls_all.execute();
	trace('running show_all method');
}


private function show_all_result(e:SQLEvent):void {
	var data:Array = sqls_all.getResult().data;
	trace('got a result');
	//trace(data.length);
}
	

private function retrieve_data():void {
	var stmt:SQLStatement = new SQLStatement();;
	stmt.sqlConnection = sql_connection;
	stmt.text = "SELECT * FROM notes";
	stmt.execute();
	var result:SQLResult = stmt.getResult();
	trace('retrieved statement');
	trace(result);
}


/////// copied and pasted from elsewhere to test db stuff /////////



// method to remove row from database.
private function remove():void
{
	// sql statment to delete from our test_table the row that has the same number in number column as our selected row from datagrid
	//sqls.text = "DELETE FROM test_table WHERE id="+dp[dg.selectedIndex].id;
	sqls.execute();
}
// method which gets called when we recive an error  from sql connection or sql statment and displays the error in the alert
private function error(e:SQLErrorEvent):void
{
	Alert.show(e.toString());
}

// random string generator
private function generateRandomString(strlen:Number):String{
	var chars:String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	var num_chars:Number = chars.length - 1;
	var randomChar:String = "";
	
	for (var i:Number = 0; i < strlen; i++){
		randomChar += chars.charAt(Math.floor(Math.random() * num_chars));
	}
	return randomChar;
}
