//A macro to SUM and MAX project all open images with a specified number of slices from the current active slice
	//Gobal variable holding the number of slices to project 
	var slicenum = 7;

	//Macro to set number of projected slices
	macro "Set number of slices to project [6]" {
		slicenum = getNumber("Number of slices to project", 7);
	}

	//Macro to do projections
	macro "MaxSumProjector_v3 [F3]" {
		//Get condition and root directory
			condition = getString("Experiment/Condition", "-");
			dir = getDirectory("Choose a Directory");

		//Verify number of slices to project
			Dialog.create("Number of slices");
			Dialog.addMessage("Number of slices: " + slicenum);
			Dialog.addMessage("Press 'ok' to proceed or 'cancel' to abort");
			Dialog.show();
		
		//Name of new folders to hold projections (one per projection type)
			MaxProj = dir+"//MaxProj_"+condition+"//";
			SumProj = dir+"//SumProj_"+condition+"//";

		//Create new folders
			File.makeDirectory(MaxProj);
			File.makeDirectory(SumProj);

		//enter batch mode
		setBatchMode(true);
		
		//Loop through open images, generating and saving projections
  			for (i=1; i<=nImages; i++) {

  				//select relevant image
   				selectImage(i);
   				//store name of current image
  				title=getTitle();
  				
  				//Find slices to project
   					//extract info about active channel/slice/frame
					Stack.getPosition(channel, slice, frame);
					//calculate which slice to project to (from desired number of slices and current slice)
					end=slice+slicenum-1;
						
				//Sum project and save
					//SUM project from current slice to calculated end slice
					run("Z Project...", "start=slice stop=end projection=[Sum Slices]");
					//Save projection as tiff with the prefix of "SUM_" in SUM projections folder
					saveAs("tiff", SumProj+"SUM_"+title);
					//Close projection
					close();

				//Max project and save
					//reselect relevant image
					selectImage(i);
					//MAX project from current slice to calculated end slice
					run("Z Project...", "start=slice stop=end projection=[Max Intensity]");
					//Save projection as tiff with the prefix of "MAX_" in MAX projections folder
					saveAs("tiff", MaxProj+"MAX_"+title);
					//Close projection
					close();
				} 

		//exit batch mode
		setBatchMode(false);
		//close all images
		close("*");
	}