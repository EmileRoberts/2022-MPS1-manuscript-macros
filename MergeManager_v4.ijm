//A macro to change grayscale channel/create merges of all open images
macro "MergeManager_v4 [F7]" {
	
	//Design dialogue box
		Dialog.create("Select channel colours");
		//Arrays of possible inputs for merge colours or grayscale channel
			items = newArray("-", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", "Grays");
			items2 = newArray("-", "1", "2", "3", "4");
		//Add options for each channel's colour
			Dialog.addChoice("Ch1:", items, "-");
			Dialog.addChoice("Ch2:", items, "-");
			Dialog.addChoice("Ch3:", items, "-");
			Dialog.addChoice("Ch4:", items, "-");
			Dialog.addChoice("Grayscale", items2, "-");

	//Show Dialogue box
	Dialog.show();
	
	//Store inputs as variables
		c1 = Dialog.getChoice();
		c2 = Dialog.getChoice();
		c3 = Dialog.getChoice();
		c4 = Dialog.getChoice();
		grays = Dialog.getChoice();

	//Create array to list input variables
	Chs = newArray(c1, c2 ,c3, c4);

	//Create array for active channels in merge (0 is not active, 1 is active)
	Display = newArray("0", "0", "0", "0");

	//Change active channels based on inputs (for merge)
		//loop through channels
		for (i = 0; i < Chs.length; i++) {
			//if channel has been assigned a colour (input is not the default '-')
			if (Chs[i] != "-") {
				//change that channel's as active in the array of active channels (Display)
				Display[i] = "1";
			} 
		}

	//enter batch mode
	setBatchMode(true);

	//Set all images to display the desired merge
		//loop through open images
	 	for (j=1; j<=nImages; j++) {
	 		//select current image
  			selectImage(j);
  			//loop through channels
			for (i = 0; i<Chs.length; i++) {
				//channels start at 1 not 0, set channel accordingly
				Stack.setChannel(i+1);
				//if a channel's colour has been entered (is not the default '-')
				if (Chs[i] != "-") {
					//run function to turn the current channel the specified colour
					run(Chs[i]);
				}
			}
			//Display the stack as composite
			Stack.setDisplayMode("composite");
			//Display channels which have been assigned a colour 
			//The array "Display" from earlier is here made into a 4 character string and passed as an arguement to setActiveChannels
			Stack.setActiveChannels(Display[0]+Display[1]+Display[2]+Display[3]);
		}

	//Set to grayscale if selected
		//condition for if a grayscale channel has been specified (runs if channel is not the default '-')
		if (grays != "-") {
			//loop through open images
  			for (i=1; i<=nImages; i++) {
  				//select current image
  				selectImage(i);
  				//select the input channel
  				Stack.setChannel(grays);
  				//set the display mode as grayscale
  				Stack.setDisplayMode("grayscale");
  			}
	}

	//exit batch mode
	setBatchMode(false);
}