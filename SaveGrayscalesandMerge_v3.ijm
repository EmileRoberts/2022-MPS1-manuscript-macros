//A macro to save a merge of the current image, as well as individual channels in grayscale
macro "SaveGrayscalesandMerge_v3 [F8]" {

	//Get root name and directory for saving
		RootName = getString("Condition", "-");
		dir = getDirectory("Choose where to save"); 

	//get image title and active channels 	
		title = getTitle();
		Stack.getActiveChannels(string);

	//Make new directory for condition
	CurrentCondition = dir+"//"+RootName+"//"
	File.makeDirectory(CurrentCondition);

	selectWindow(title);
	saveAs("tiff", CurrentCondition+title);
	
	//enter batch mode
	setBatchMode(true);
	
	//Duplicate image, set active channel and save as RGB
		//duplicate  image
		run("Duplicate...", "duplicate");
		//rename duplcated image "dupli"
		rename("dupli");
		//set the active channels as they were in the original image
		Stack.setActiveChannels(string);
		//convert to RGB (creates a new image)
		run("RGB Color");
		//Save RGB image
		saveAs("tiff", CurrentCondition+RootName+" merge");
		//close RGB image
		close();
		//close duplicated image
		close("dupli");

	//select origninal image and split channels
		selectImage(title);
		//change to grayscale (such that split channels will be grayscale)
		Stack.setDisplayMode("grayscale");
		//split
		run("Split Channels"); 

	//Save split channels as variables 
		C1 = "C1-"+title;
		C2 = "C2-"+title;
		C3 = "C3-"+title;
		C4 = "C4-"+title;

	//Create arrays of channel images and their names
		//Array of grayscale channels (images)
		Channels = newArray(C1, C2, C3, C4)
		//Array of channel names (strings)
		ChNames = newArray("C1", "C2", "C3", "C4")

	//Save an 8-bit tiff of each channel 
		for (i = 0; i < Channels.length; i++) {
		//select relevant channel
		selectImage(Channels[i]);
			//convert to 8-bit image
			run("8-bit");
			//save
			saveAs("tiff", CurrentCondition+RootName+" "+ChNames[i]);
			//close channel
			close();
		}

	//exit batch mode
	setBatchMode(false);
	
}