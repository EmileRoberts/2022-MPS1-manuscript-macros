// A macro for measuring signal at attached and unattached kinetochores and corresponding background signal

var KinetochoreChannel = 3;
var xPoints = newArray(0);
var yPoints = newArray(0);
var NumKTs = 20;
var xBackgroundPoints = newArray(0);
var yBackgroundPoints = newArray(0);
var size = 8;
var iteration = 0;
var xCoord = 0;
var yCoord = 0;
var BackgroundArea = 52;
var ROIPixArray = newArray(0);
var DistanceLimit = 6;
var SelectionMethod = "Auto";
var MarkerChannel = 4;
var AttProm = 80;
var Proceed = false;
var xPointsAtt = newArray(0);
var yPointsAtt = newArray(0);
var xPointsUna = newArray(0);
var yPointsUna = newArray(0);
var AttachedCount = 0;
var UnattachedCount = 0;
var xOverlap = newArray(0);
var yOverlap = newArray(0);
var Overlapping = false;

macro "Attachment Counter Options [2] " {
	Dialog.create("Attachment Counter Options");
	Dialog.addChoice("Kinetochore channel", newArray("1", "2", "3", "4"), KinetochoreChannel);
	Dialog.addChoice("Marker channel", newArray("1", "2", "3", "4"), MarkerChannel);
	Dialog.addNumber("ROI diameter (px)", size);
	Dialog.show();

	KinetochoreChannel = parseInt(Dialog.getChoice());
	MarkerChannel = parseInt(Dialog.getChoice());
	size = Dialog.getNumber();
}


macro "Attachment Counter v3 [1]" {

	  //clear ROI manager if it contains ROIs
        if (roiManager("count") > 0) {
            roiManager("delete");
        }
    
    run("Select None");

	ReinitialiseVars();
	
	// Get name of current image and clear existing selections
    ParentImage = getTitle();
    FilePath = getInfo("image.directory");
    
    run("Select None");

    // Auto-detect kinetochores
    KinetochoreThresholderA();
    KinetochorePoints();
    ReduceFalsePositivesA();
    CloseIntermediates();

    // Let user edit kinetochore selection
    setTool("multipoint");
    waitForUser("select anything I missed");
    getSelectionCoordinates(xpoints, ypoints);
	xPoints = xpoints;
	yPoints = ypoints;

	// Select kinetochores
    PlaceROIsManual();

	TransformAttachmentChan();
	
	while (!Proceed) {
		CreateInputDialog();
		AttProm = Dialog.getNumber();
		Proceed = Dialog.getCheckbox();
	
		IterativeFindMaxima();
	}

	GetAttachmentCoords();
	close("Attachments");
	close("Attachments tophat");
    SetInitialClasses();

    newImage("1", "8-bit white", 50, 50, 1);

    while (isOpen("1") == true) {
		SwitchRoi();
		wait(100);
    }
    
    roiManager("Save", FilePath + ParentImage + "_ROIs.zip");
    
    // Get x,y coords of attached and unattached KTs separately
    GetKinetochoreCoords();
    
    TestForOverlap();
    Array.print(xOverlap);
    
    roiManager("deselect");
	roiManager("delete");
	run("Select None");
	
	MeasureAttached();
	MeasureUnattached();
	
	function MeasureAttached() {
		
		for (i = 0; i < xPointsAtt.length; i++) {
            //define origin of oval (top left corner)
            xCoord = xPointsAtt[i] - size / 2;
            yCoord = yPointsAtt[i] - size / 2;
            //generate oval selection and add to ROI manager
            setSlice(KinetochoreChannel);
            makeOval(xCoord, yCoord, size, size);

            roiManager("add");
        }
        
        waitForUser;
        
        // Measure KTs
   			selectWindow(ParentImage);
    		MultiMeasureROIs();
    		PopulateKTResults("Attached Kinetochores", xPointsAtt, yPointsAtt);

    		// Generate background selections for all measured KTs
    		KinetochoreThresholderA();
    		setBatchMode(true);
    		GetBackgrounds(xPointsAtt, yPointsAtt);
    		setBatchMode(false);

    		// Measure Backgrounds
    		selectWindow(ParentImage);
    		MultiMeasureROIs();
    		RecordCoords();
    		close("BinaryKinetochores");
    		PopulateBackgroundResults("Attached Backgrounds");

   			close("TopHat");

	}
	
	
		function MeasureUnattached() {
		
		for (i = 0; i < xPointsUna.length; i++) {
            //define origin of oval (top left corner)
            xCoord = xPointsUna[i] - size / 2;
            yCoord = yPointsUna[i] - size / 2;
            //generate oval selection and add to ROI manager
            setSlice(KinetochoreChannel);
            makeOval(xCoord, yCoord, size, size);

            roiManager("add");
        }
        
        waitForUser;
        
        // Measure KTs
   			selectWindow(ParentImage);
    		MultiMeasureROIs();
    		PopulateKTResults("Unattached Kinetochores", xPointsUna, yPointsUna);

    		// Generate background selections for all measured KTs
    		KinetochoreThresholderA();
    		setBatchMode(true);
    		GetBackgrounds(xPointsUna, yPointsUna);
    		setBatchMode(false);

    		// Measure Backgrounds
    		selectWindow(ParentImage);
    		MultiMeasureROIs();
    		RecordCoords();
    		close("BinaryKinetochores");
    		PopulateBackgroundResults("Unattached Backgrounds");

   			close("TopHat");

	}
	
    function KinetochoreThresholderA() {
        // extraction of binarised kinetochore marker channel
        // returns thresholded binary image of kinetochore marker channel

        // Duplicate channel containing kinetochore marker
        selectWindow(ParentImage);
        run("Duplicate...", "title=[KT channel] duplicate channels=" + KinetochoreChannel);
        rename("Kinetochores");

        //setBatchMode(true);

        // Convert to 8-bit and run TopHat transform
        run("8-bit");
        run("Morphological Filters", "operation=[White Top Hat] element=Disk radius=4");
        OGTopHat = getTitle();
        run("Duplicate...", "title=TopHat");
        selectWindow(OGTopHat);
		run("8-bit");
        // Threshold 
       	setAutoThreshold("Default dark");
       	run("Convert to Mask");

       	
        rename("BinaryKinetochores");
        run("Dilate");
        close("Kinetochores");

        setBatchMode(false);

    }

    function KinetochorePoints() {

        
        // Finds kinetochores via maxima
        //variables
        //initial noise value (higher=more stringent)
        noise_value = 20;
        //increment with which to decrease noise value until nPoints is achieved/surpassed
        increment = 1;
        //current number of points
        xPoints = 0;
        //minumum number of points to be found
        nPoints = 110;

        //clear ROI manager if it contains ROIs
        if (roiManager("count") > 0) {
            roiManager("delete");
        }

        //Normalise TopHat
        selectWindow("TopHat");
        run("Enhance Contrast...", "saturated=0.001 normalize");

		selectWindow(ParentImage);
		Stack.setChannel(KinetochoreChannel);
		setTool("freehand");
        waitForUser("Make a selection if needed");
        if (selectionType() != -1) {

        	run("Add to Manager");
        }
        

        //run "find maxima" with decreasingly stringent parameters until > [nPoints] maxima found
        do {

        	selectWindow("TopHat");
        	if (roiManager("count") != 0) {
        		roiManager("select", 0);
        	}
            //decrease noise value by increment
            noise_value = noise_value - increment;
            //run find maxima based on noise value
            run("Find Maxima...", "prominence=" + noise_value + " output=[Point Selection]");
            //find out which points have been selected
            getSelectionCoordinates(xPoints, yPoints);
        }

        //loop through the do loop until the number of points detected is equal to or greater than nPoints
        while (xPoints.length < nPoints);

		if (roiManager("count") != 0) {
        		roiManager("select", 0);
        }
        	
        run("Find Maxima...", "prominence=" + noise_value + " output=[Single Points]");
        rename("KTPoints");

        close("TopHat");

		if (roiManager("count") != 0) {
        	roiManager("deselect");
        	roiManager("delete");
        }
    }


    function ReduceFalsePositivesA() {
        // Eliminate false positives in attachment marker channel
        // Checks if there are kinetochores where attachments have been marked
        // Overlays remaining attachments on parent image

        // Eliminate attachments where there are no kinetochores
        imageCalculator("AND create", "KTPoints", "BinaryKinetochores");
        rename("OverlappingPoints");
        //run("Invert");

        setBatchMode(true);

        // Find maxima to generate points selection
        selectWindow("OverlappingPoints");
        run("Invert");
        run("Select None");
        run("Find Maxima...", "prominence=8 output=[Point Selection]");

        selectImage(ParentImage);
        Stack.setChannel(KinetochoreChannel);
        run("Restore Selection");

        setBatchMode(false);


    }

    function CloseIntermediates() {
        // Close windows created during selection of kinetochores
        close("BinaryKinetochores");
        close("KTPoints");
        close("OverlappingPoints");
        close("Result of KTPoints");
    }

	function SortPoints() { 
	// Sort list of points by Kinetochore intensity
		// Place ROIs over all kinetochores
		for (i = 0; i < xPoints.length; i++) {
            //define origin of oval (top left corner)
            xCoord = xPoints[i] - size / 2;
            yCoord = yPoints[i] - size / 2;
            //generate oval selection and add to ROI manager
            setSlice(KinetochoreChannel);
            makeOval(xCoord, yCoord, size, size);

            roiManager("add");
        }

		// Measure mean and coords of all points
        run("Set Measurements...", "mean redirect=None decimal=3");
        roiManager("multi-measure append");
        
        // Add coords to results table
        for (i = 0; i < xPoints.length; i++) {
        	setResult("X", i, xPoints[i]);
        	setResult("Y", i, yPoints[i]);
        }

		// Sort results
		Table.sort("Mean");

		// Update xPoints and yPoints with sorted coords
		xPoints = Table.getColumn("X");
		yPoints = Table.getColumn("Y");
		
		close("Results");
		roiManager("deselect");
		roiManager("delete");

	}

	
    function PlaceROIsAuto() {
	// Function to select [NumKTs] elements from the middle of xPoints and yPoints arrays
	// Then places ovals centered on remaining points

       	NumberPoints = xPoints.length;

        xPoints = Array.trim(xPoints, NumberPoints - NumKTs*2);
        yPoints = Array.trim(yPoints, NumberPoints - NumKTs*2);

        Array.reverse(xPoints);
        Array.reverse(yPoints);
        
		xPoints = Array.trim(xPoints, NumKTs);
        yPoints = Array.trim(yPoints, NumKTs);
        

        //select ovals of [size]x[size] around maxima and add each to the ROI manager
        //loop through maxima
        for (i = 0; i < xPoints.length; i++) {
            //define origin of oval (top left corner)
            xCoord = xPoints[i] - size / 2;
            yCoord = yPoints[i] - size / 2;
            //generate oval selection and add to ROI manager
            setSlice(KinetochoreChannel);
            makeOval(xCoord, yCoord, size, size);

            roiManager("add");
        }

        roiManager("show all without labels");
    }

    function PlaceROIsManual() {
	// Places ovals centered on points specified by xPoints and yPoints

	selectWindow(ParentImage);

        //select ovals of [size]x[size] around maxima and add each to the ROI manager
        //loop through maxima
        for (i = 0; i < xPoints.length; i++) {
            //define origin of oval (top left corner)
            xCoord = xPoints[i] - size / 2;
            yCoord = yPoints[i] - size / 2;
            //generate oval selection and add to ROI manager
            setSlice(MarkerChannel);
            makeOval(xCoord, yCoord, size, size);

            roiManager("add");
        }

        roiManager("show all without labels");
        roiManager("deselect");
        RoiManager.setGroup(3);

    }

    function MultiMeasureROIs() {
        //multimeasure ROIs in ROI manger, appending to existing results table
        run("Set Measurements...", "area mean display redirect=None decimal=3");
		roiManager("deselect");
        roiManager("multi-measure measure append");
        //clear ROI manage
        roiManager("delete");
        run("Select None");
    }

    function PopulateKTResults(KTName, xList, yList) {
        // Updates KT results table with data from the current cell

        // Generate the results table if it isn't open
        if (isOpen(KTName) == 0) {
			Means = Table.getColumn("Mean");
            Table.rename("Results", KTName);
             for (i = 0; i < Means.length; i++) {
            	 if (TestForOverlap(xList[i], yList[i]) == 1) {
                		Table.set("Overlap", i, "Y");
                }
             }

        } else {

            // Get results columns as arrays
            selectWindow("Results");
            Labels = Table.getColumn("Label");
            Areas = Table.getColumn("Area");
            Means = Table.getColumn("Mean");
            Channels = Table.getColumn("Ch");

            close("Results");

            // Populate KT Results with arrays
            selectWindow(KTName);
            ExistingMeans = Table.getColumn("Mean");
            Resultslength = ExistingMeans.length;

            for (i = 0; i < Means.length; i++) {
                Table.set("Label", i + Resultslength, Labels[i]);
                Table.set("Area", i + Resultslength, Areas[i]);
                Table.set("Mean", i + Resultslength, Means[i]);
                Table.set("Ch", i + Resultslength, Channels[i]);
                if (TestForOverlap(xList[i], yList[i]) == 1) {
                	Table.set("Overlap", i + Resultslength, "Y");
                }
            }

            Table.update(KTName);

        }

    }

    function GetBackgrounds(xInput, yInput) {

        // Set up loop for each point
        for (i = 0; i < xInput.length; i++) {

            xBackgroundPoints = newArray(0);
            yBackgroundPoints = newArray(0);

            iteration = 0;

            // Select point
            xCoord = xInput[i];
            yCoord = yInput[i];

            while (xBackgroundPoints.length < 52) {
                MakeRadialSelection();
            }

			
            ROIPixArray = newArray(xBackgroundPoints.length);
            for (j = 0; j < xBackgroundPoints.length + i; j++) {
                ROIPixArray[j] = j;
            }

            Array.reverse(ROIPixArray);
            ROIPixArray = Array.trim(ROIPixArray, ROIPixArray.length - i);
			
            roiManager("select", ROIPixArray);

            roiManager("Combine");
            selectWindow(ParentImage);
            run("Restore Selection");
            roiManager("add");
            run("Select None");


            roiManager("select", ROIPixArray);
            roiManager("delete");

        }

    }



    function MakeRadialSelection() {
        // Make selection
        makeRectangle(xCoord - (size + iteration) / 2, yCoord - (size + iteration) / 2, size + iteration, size + iteration);
        // Extract points touching selection
        run("Interpolate", "interval = 1");
        getSelectionCoordinates(xpoints, ypoints);

        // Loop through points to find if they lie outside of mask
        for (i = 0; i < xpoints.length; i++) {

            selectWindow("BinaryKinetochores");
            makeRectangle(xpoints[i], ypoints[i], 1, 1);
            run("Measure");
            Value = getResult("Mean", 0);
            run("Clear Results");

            if (Value == 0 && xBackgroundPoints.length < BackgroundArea) {
                xBackgroundPoints = Array.concat(xBackgroundPoints, xpoints[i]);
                yBackgroundPoints = Array.concat(yBackgroundPoints, ypoints[i]);
                roiManager("add");
                
            } 
            
        }
        
		iteration = iteration + 2;
        run("Select None");
        

    }

    function RecordCoords() {
        // Add coords to results tables
        for (i = 0; i < NumKTs; i++) {
            setResult("x", i, xPoints[i]);
            setResult("x", i + NumKTs, xPoints[i]);
            setResult("x", i + NumKTs*2, xPoints[i]);
            setResult("x", i + NumKTs*3, xPoints[i]);

            setResult("y", i, yPoints[i]);
            setResult("y", i + NumKTs, yPoints[i]);
            setResult("y", i + NumKTs*2, yPoints[i]);
            setResult("y", i + NumKTs*3, yPoints[i]);
        }
        
        updateResults();
    }

    function PopulateBackgroundResults(BackName) {
        // Updates KT results table with data from the current cell

        // Generate the results table if it isn't open
        if (isOpen(BackName) == 0) {

            Table.rename("Results", BackName);

        } else {

            // Get results columns as arrays
            selectWindow("Results");
            Labels = Table.getColumn("Label");
            Areas = Table.getColumn("Area");
            Means = Table.getColumn("Mean");
            Channels = Table.getColumn("Ch");
            xValues = Table.getColumn("x");
            yValues = Table.getColumn("y");

            close("Results");

            // Populate Background Results with arrays
            selectWindow(BackName);
            ExistingMeans = Table.getColumn("Mean");
            Resultslength = ExistingMeans.length;

            for (i = 0; i < Means.length; i++) {
                Table.set("Label", i + Resultslength, Labels[i]);
                Table.set("Area", i + Resultslength, Areas[i]);
                Table.set("Mean", i + Resultslength, Means[i]);
                Table.set("Ch", i + Resultslength, Channels[i]);
                Table.set("x", i + Resultslength, parseInt(xValues[i]));
                Table.set("y", i + Resultslength, parseInt(yValues[i]));
            }

            Table.update(BackName);
        }

    }

    function RemoveOverlappingPoints() { 
		// Removes points which are too close together from xPoints and yPoints
		
		getSelectionCoordinates(xPoints, yPoints);

		// Create clone of xPoints and yPoints to output into
		xPointsOut = xPoints;
		yPointsOut = yPoints;
		
		// Compare each point in xPoints and yPoints to all other points one at a time
		for (i = 0; i < xPoints.length; i++) {
			xPoint = xPoints[i];
			yPoint = yPoints[i];
			// Loop for comparison between current point and all other points
			for (j = 0; j < xPoints.length; j++) {
				
				Distance = DistanceCalc(xPoint, yPoint, xPoints[j], yPoints[j]);
					// Check if the current distance is smaller than the limit and not 0 (0 is a self-comparison)
					if (Distance != 0 && Distance < DistanceLimit) {
						xPointsOut[i] = "-";
						yPointsOut[i] = "-";
						
					} 
				
			}
			
		}

		// Remove points which failed the distance check from xPointsOut and yPointsOut and assign to xPoints and yPoints (global)
		xPoints = Array.deleteValue(xPointsOut, "-");
		yPoints = Array.deleteValue(yPointsOut, "-");

    }

    
	function DistanceCalc(x1, y1, x2, y2) {
		
    	//Function to output distances between two points (taken from http://imagej.1557.x6.nabble.com/distribution-analysis-nearest-neighbourhood-td5004447.html)
   		//Pythagoras' theorem to calculate euclidian distance
    	sum_difference_squared = pow(x2 - x1, 2) + pow(y2 - y1, 2);
    	output = pow(sum_difference_squared, 0.5);
    	return output;
    
	}

	function SwitchRoi() { 
	// Gets user to select a ROI then switches its group
		setTool(12);

		// Wait for a ROI to be selected
		while (roiManager("index") == -1) {
			wait(10);
		}

		if (isOpen("1") == true) {
		// Change group of selected ROI and update count if the ROI has not already been selected
		if (Roi.getGroup() != 2) {
			RoiManager.setGroup(2);
			roiManager("deselect");
		} else {
			RoiManager.setGroup(3);
			roiManager("deselect");
		}

	}
	}


	function ReinitialiseVars() { 
		
		xPoints = newArray(0);
		yPoints = newArray(0);
		xBackgroundPoints = newArray(0);
		yBackgroundPoints = newArray(0);
		iteration = 0;
		xCoord = 0;
		yCoord = 0;
		ROIPixArray = newArray(0);
		SelectedKTs = 0;
		AttProm = 80;
		Proceed = false;
		AttachedCount = 0;
		UnattachedCount = 0;

	}

	function TransformAttachmentChan() { 
		// Tophat and normalisation of attachment channel
		selectWindow(ParentImage);
		run("Select None");
        run("Duplicate...", "title=[KT channel] duplicate channels=" + MarkerChannel);
        rename("Attachments");

        //setBatchMode(true);

        // Convert to 8-bit and run TopHat transform
        run("8-bit");
        run("Morphological Filters", "operation=[White Top Hat] element=Disk radius=4");
        rename("Attachments tophat");
        run("Enhance Contrast...", "saturated=0.001 normalize");

        // Arrange preview 
		ScreenSize = screenHeight/2;


		selectWindow("Attachments");
		setLocation(0, 0, ScreenSize, ScreenSize);
        
	}

	function IterativeFindMaxima() { 
		// User controlled find maxima
		selectWindow("Attachments tophat");
		run("Find Maxima...", "prominence="+AttProm+" output=[Point Selection]");
        selectImage("Attachments");
        Stack.setChannel(MarkerChannel);
        run("Restore Selection");
	}

	function CreateInputDialog() { 
		// Generates dialog box and records user inputs
		Dialog.create("Tweak maxima prominence");
		Dialog.addMessage("Alter prominence until roughly all attachments are found");
		Dialog.addMessage("Check proceed when happy with parameters");
		Dialog.addNumber("Prominence", AttProm);
		Dialog.addCheckbox("Proceed", false);
		Dialog.show();
	}

	function GetAttachmentCoords() { 
		// Get lists of initial attachment points
		getSelectionCoordinates(xpoints, ypoints);
		xPointsAtt = xpoints;
		yPointsAtt = ypoints;
	}

	function SetInitialClasses() { 
		// Checks if attachment points lie within ROIs and switches them accordingly
		selectWindow(ParentImage);
		for (i = 0; i < roiManager("count"); i++) {
			roiManager("select", i);
			for (j = 0; j < xPointsAtt.length; j++) {
				if (Roi.contains(xPointsAtt[j], yPointsAtt[j]) == true) {
					RoiManager.setGroup(2);
				}
			}
		}

		run("Select None");
	}

	
	function GetKinetochoreCoords() { 
		// Get list of x,y coords from each class and store to global arrays
		run("Set Measurements...", "centroid redirect=None decimal=3");
	
		// Unattached KTs
		
		RoiManager.selectGroup(3);
		roiManager("multi-measure");
		xPointsUna = Table.getColumn("X");
		yPointsUna = Table.getColumn("Y");
		run("Clear Results");
	
		// Attached KTs
		RoiManager.selectGroup(2);
		roiManager("multi-measure");
		xPointsAtt = Table.getColumn("X");
		yPointsAtt = Table.getColumn("Y");
		run("Clear Results");
		
	}
	
	function TestForOverlap() {
		// Compare each point in xPoints and yPoints to all other points one at a time
		for (i = 0; i < xPoints.length; i++) {
			xPoint = xPoints[i];
			yPoint = yPoints[i];
			// Loop for comparison between current point and all other points
			for (j = 0; j < xPoints.length; j++) {
				
				Distance = DistanceCalc(xPoint, yPoint, xPoints[j], yPoints[j]);
				
				// Check if the current distance is smaller than the limit and not 0 (0 is a self-comparison)
				if (Distance != 0 && Distance < DistanceLimit) {
					xOverlap = Array.concat(xOverlap, xPoint);
					yOverlap = Array.concat(yOverlap, yPoint);
						
				} 
			}
		}
	}
	
	function ArraysContainPoint(x, y) {
		
		for (j = 0; j < xOverlap.length; j++) {
			
			if (xOverlap[j] == x && yOverlap[j] == y) {
				
				Overlapping = true;
				
			} else {
				
				Overlapping = false;
			}
		}
	}
	
}

