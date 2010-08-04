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
private var search_focus:Boolean = false;		// this boolean indicates whether search has focus
private var title_array:Array = new Array();	// this array contains only note titles
private var title_and_text_array:Array = new Array(); 	// this contains only note title and text
private var filtered_notes_array:Array = new Array(); 	// contains filtered versions of the title_array
private var rich_array:Array = new Array(); 	// this array contains note title, text, and modified date
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
	title_and_text_array.splice(note_index, 1);
	title_and_text_array.unshift(title + " " + file_text);
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
			create_new_note();
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

// this method deletes the currently active file
private function delete_note():void {
	trace('delete_note');
	var note_list_index:uint = note_list.selectedIndex;
	if (note_list.selectedIndex == -1) {
		trace('no note is selected');
		return; // do nothing if no note is selected
	}
	search_box.text = last_explicit_query;		// this and the next line are kludgy, but currently the workaround because event.preventDefault() isn't working for cmd/ctrl+delete
	search();									
	Alert.show('Delete the note named "' + active_title + '"?', "Note delete", Alert.YES|Alert.NO, this, confirm_delete, null, Alert.YES);
}

private function confirm_delete(event:CloseEvent):void {
	trace('confirm_delete');
	if (event.detail == Alert.YES) {
		var file_name:String = search_box.text + ".txt"; 
		var file:File = File.desktopDirectory.resolvePath("Notes/" + file_name);
		if (file.exists) {
			trace ("Exists... deleting");
			file.deleteFile();
			remove_note_from_array();
			clear_search();
		}
	} 
}

// the following two functions will add/remove notes to/from the array(s) as
// notes are created or deleted
private function add_note_to_array():void {
	// add a new item to the top of the list (goes to top because it's sorted by last modified)
	trace('add_note_to_array');
	trace("Note title: " + active_title);
	note_list.dataProvider.addItemAt(active_title, 0);
	title_array.unshift(active_title);
	title_and_text_array.unshift(active_title);
}

private function remove_note_from_array():void {
	// remove item from array
	trace('remove_note_from_array');
	var remove_index:uint = title_array.indexOf(active_title);
	title_array.splice(remove_index, 1);
	title_and_text_array.splice(remove_index, 1);
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
	for (var j:uint = 0; j < title_and_text_array.length; j++) {
		if (has_a_match(title_and_text_array[j], query_words)) {
			filtered_notes_array.push(title_array[j]);
		}
	}
	note_list.dataProvider = new ArrayList(filtered_notes_array);
	trace (filtered_notes_array);
	// this block selects the first matching title name if the query
	// string matches the beginning of the title; the loop breaks as soon
	// as a match is found
	if (query.length > 0 && filtered_notes_array.length != 0) {
		for (var i:uint = 0; i < filtered_notes_array.length; i++) {
			if (filtered_notes_array[i].toString().toLowerCase().indexOf(query) == 0) {
				note_list.selectedIndex = -1; // for some reason I have to set the index to -1 (nothing selected) or reselecting an already selected index will toggle its selection; annoying!
				note_list.selectedIndex = i;	
				search_box.text = search_box.text + note_list.selectedItem.substring(query.length);
				active_title = search_box.text;
				search_box.selectRange(query.length, search_box.text.length);
				note_list.selectedIndex = i;
				if (search_box.text.toLowerCase() != note_title.text.toLowerCase()) {
					read_from_file(search_box.text);
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
		search_box.text = note_list.selectedItem;
		read_from_file(search_box.text);
	}
	search_box.selectAll();
}

private function select_previous_note():void {
	if (note_list.selectedIndex != 0) {
		note_list.selectedIndex -= 1;
		search_box.text = note_list.selectedItem;
		read_from_file(search_box.text);
	}
	search_box.selectAll();
}

// determine whether the search box identifies a new note or an existing note
// if new, create new note with current search box title
// if existing, load the existing note
private function activate_note_or_create_new():void {
	// clear whatever's currently in the main text area in preparation for the new note
	trace('activate_note_or_create_new');
	main_text_area.text = '';
	active_title = search_box.text;
	read_from_file(search_box.text);
	main_text_area.setFocus();
	if (note_list.selectedIndex == -1) {
		note_list.selectedIndex = 0;	
	}
}

// timer that saves the active note every 5 seconds if it's changed; ideally we'll set up a better method 
// than a straight up timer for of regular saving
private var last_save:String = '';
private var save_timer:Timer = new Timer(5000);


// crude save function
private function save(event:TimerEvent):void {
	if (last_save != main_text_area.text && note_title.text != '') {
		var f:File = File.desktopDirectory.resolvePath("Notes/" + active_title + ".txt");
		if (f.exists) {
			trace("Saving via timer");
			write_to_file(active_title, main_text_area.text); // this should prob be a lot more robust
			last_save = main_text_area.text;
		}
	}
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
	title_and_text_array = [];
	for (var k:uint = 0; k < rich_array.length; k++) {
		title_array.push(rich_array[k].title); //+ rich_array[k].text);
		title_and_text_array.push(rich_array[k].title + " " + rich_array[k].text);
		trace (rich_array[k].title);
	}
	var convert_list:ArrayList = new ArrayList(title_array);
	note_list.dataProvider = convert_list;
	// rich_note_list.dataProvider = rich_list;
	// set save timer
	save_timer.addEventListener(TimerEvent.TIMER, save);
	save_timer.start();
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
		write_to_file(active_title, main_text_area.text);
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
	var request:URLRequest = create_simplenote_request("https://simple-note.appspot.com/api/login","email=adam@lifehacker.com&password=testpass"); 
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
	urlLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, url_handler_1)
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
	trace(e.target.data);
	var note_array:Array = (JSON.decode(e.target.data) as Array);
	trace(note_array);
	var obj:Object = note_array[0];
	trace(obj.deleted + ' ' + obj.modify + ' ' + obj.key);
	// loop through the array of notes
	for (var i:uint; i < note_array.length; i++) {
		// check to see if the note exists in the local database
		// if not, retrieve note from simplenote and add to/update database
		trace(note_array[i].key);
		var temp_sqls:SQLStatement = new SQLStatement();
		temp_sqls.sqlConnection = sqlc;
		temp_sqls.text = "INSERT INTO notes (key, modify, title, text) VALUES('" + note_array[i].key + "', '" + note_array[i].modify + "', '" + note_array[i].title + "', '" + note_array[i].text + "');";
		temp_sqls.execute();

		// add_item_to_db(note_array[i].key, note_array[i].modify, note_array[i].title, '');
		//create_record(note_array[i].key, note_array[i].modify, '', '');
		// also check if the modified date is the same; if local modified date
		// is more recent, sync update to simplenote; if simplenote modified date
		// is more recent, pull latest from simplenote
	}
	show_all();
	//create_db_table();
	//create_record(note_array[0].key, note_array[0].modify, '', '');
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
	sqlc.openAsync(db);
	// we need to set some event listeners so we know if we get an sql error, when the database is fully opened and to know when we recive a resault from an sql statment. The last one is uset to read data out of database.
	sqlc.addEventListener(SQLEvent.OPEN, db_opened);
	sqlc.addEventListener(SQLErrorEvent.ERROR, error);
	sqls.addEventListener(SQLErrorEvent.ERROR, error);
	sqls.addEventListener(SQLEvent.RESULT, statement_result);
	
}

private function db_opened(e:SQLEvent):void
{
	trace("database successfully opened");
	// when the database is opened we need to link the SQLStatment to our SQLConnection, so that sql statments for the right database.
	// if you don't set this connection you will get an error when you execute sql statment.
	sqls.sqlConnection = sqlc;
	// in property text of our SQLStatment we write our sql command. We can also combine sql statments in our text property so that more than one statment can be executed at a time.
	// in this sql statment we create table in our database with name "test_table" with three columns (id, first_name and last_name). Id is an integer that is auto incremented when each item is added. First_name and last_name are columns in which we can store text
	// If you want to know more about sql statments search the web.
	sqls.text = "CREATE TABLE IF NOT EXISTS notes ( id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT, modify TEXT, title TEXT, text TEXT );";
	// after we have connected sql statment to our sql connection and writen our sql commands we also need to execute our sql statment.
	// nothing will change in database until we execute sql statment.
	sqls.execute();
	// after we load the database and create the table if it doesn't already exists, we call refresh method which i have created to populate our datagrid
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
		sqls.text = "INSERT INTO notes (key, modify, title, text) VALUES('" + key + "', '" + modify + "', '" + title + "', '" + text + "');";
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
	trace('show all');
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
	trace(data.length);
}
	
// below not currently in use
private function db_create_handler(event:SQLEvent):void {
	var statement:SQLStatement = new SQLStatement();
	statement.sqlConnection = sql_connection;
	statement.text = "CREATE TABLE IF NOT EXISTS notes ( id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT, modify TEXT, title TEXT,	text TEXT);";
	statement.execute();
	var result:SQLResult = statement.getResult();
	trace("Table created");
	//sql_connection.close();
	trace('db created');
}


private function create_db_table():void {
	var statement:SQLStatement = new SQLStatement();
	statement.sqlConnection = sql_connection;
	//statement.text = "CREATE TABLE IF NOT EXISTS test_table ( id INTEGER PRIMARY KEY AUTOINCREMENT, first_name TEXT, last_name TEXT);";
	statement.text = "CREATE TABLE IF NOT EXISTS notes ( id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT, modify TEXT, title TEXT,	text TEXT);";
	//statement.addEventListener(SQLEvent.RESULT, sql_result);
	statement.execute();
	//var result:SQLResult = statement.getResult();
	trace("Table created");
	//sql_connection.close();
	trace('db created');
}


private function db_open_handler(event:SQLEvent):void {
	trace("Db is open for business");
}

private function create_record(key:String, modify:String, title:String, text:String):void {
	var stmt:SQLStatement = new SQLStatement();
	stmt.sqlConnection = sql_connection;
	stmt.text = "INSERT INTO notes (" +
		"key, modify, title, text) " +
		"VALUES (" +
		"'keyvalue', 'modifydate', 'title', 'text')";
	stmt.execute();
	var result:SQLResult = stmt.getResult();
	trace("Data inserted");
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