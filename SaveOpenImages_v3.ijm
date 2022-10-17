
//A macro to save all open images according to a common rootname
macro "SaveOpenImages_v3 [F2]" {

	//Get user inputs (rootname with which to save, directory in which to save in)
		RootName = getString("Experiment/Condition", "-")
		dir = getDirectory("Choose a Directory");

	//Create new folder in directory using rootname
		//specify path for new directory (stored as new dir)
		newdir = dir+"//"+RootName+"//";
		//make new directory
		File.makeDirectory(newdir);

	//enter batch mode
	setBatchMode(true);

	//Loop through open images and saves as tiffs
		//loop throuh open images
		for (i=1;i<=nImages;i++) {
			//select relevant image
        	selectImage(i);
        	//save as a tiff - specified path (in new directory) serves to name image (name will be Rootname+" Cell"+i)       
       	 	saveAs("tiff", newdir+RootName+" Cell"+i);
		}

	//exit batch mode
	setBatchMode(false);
} 