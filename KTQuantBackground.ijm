// A macro to measure foci (kinetochores) and non-overlapping background regions for each foci

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
var DistanceLimit = 8;
var SelectedKTs = 0;
var RemoveOverlaps = false;
var SelectionMethod = "Auto";
var MarkerChannel = 4;

macro "KT Quant Background [3]" {

	ReinitialiseVars();
	
	// Get name of current image and clear existing selections
    ParentImage = getTitle();
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

	// Remove points which are too close together if requested
	if (RemoveOverlaps == true) {
		RemoveOverlappingPoints();
	}
    
    // Select kinetochores automatically or manually as requested
    if (SelectionMethod == "Auto") {
    	SortPoints();
    	PlaceROIsAuto();
    } else {
    	PlaceROIsManual();
   		while (SelectedKTs < NumKTs) {
    		SwitchRoi();
    	}
    	close("Log");
		PreserveSelectedKTs();
    }
    

    // Measure KTs
    selectWindow(ParentImage);
    MultiMeasureROIs();
    PopulateKTResults();

    // Generate background selections for all measured KTs
    KinetochoreThresholderA();
    setBatchMode(true);
    GetBackgrounds();
    setBatchMode(false);

    // Measure Backgrounds
    selectWindow(ParentImage);
    MultiMeasureROIs();
    RecordCoords();
    close("BinaryKinetochores");
    PopulateBackgroundResults();

    close("TopHat");


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
        //run("Invert");
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

    function PopulateKTResults() {
        // Updates KT results table with data from the current cell

        // Generate the results table if it isn't open
        if (isOpen("KT Results") == 0) {

            Table.rename("Results", "KT Results");

        } else {

            // Get results columns as arrays
            selectWindow("Results");
            Labels = Table.getColumn("Label");
            Areas = Table.getColumn("Area");
            Means = Table.getColumn("Mean");
            Channels = Table.getColumn("Ch");

            close("Results");

            // Populate KT Results with arrays
            selectWindow("KT Results");
            ExistingMeans = Table.getColumn("Mean");
            Resultslength = ExistingMeans.length;

            for (i = 0; i < Means.length; i++) {
                Table.set("Label", i + Resultslength, Labels[i]);
                Table.set("Area", i + Resultslength, Areas[i]);
                Table.set("Mean", i + Resultslength, Means[i]);
                Table.set("Ch", i + Resultslength, Channels[i]);
            }

            Table.update("KT Results");

        }

    }

    function GetBackgrounds() {

        // Set up loop for each point
        for (i = 0; i < xPoints.length; i++) {

            xBackgroundPoints = newArray(0);
            yBackgroundPoints = newArray(0);

            iteration = 0;

            // Select point
            xCoord = xPoints[i];
            yCoord = yPoints[i];

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

    function PopulateBackgroundResults() {
        // Updates KT results table with data from the current cell

        // Generate the results table if it isn't open
        if (isOpen("Background Results") == 0) {

            Table.rename("Results", "Background Results");

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

            // Populate KT Results with arrays
            selectWindow("Background Results");
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

            Table.update("Background Results");
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

		print("\\Clear");
		print("Please select KTs of interest");
		print("Number of KTs selected: " + SelectedKTs + "/" + NumKTs);

		// Wait for a ROI to be selected
		while (roiManager("index") == -1) {
			wait(10);
		}

		// Change group of selected ROI and update count if the ROI has not already been selected
		if (Roi.getGroup() != 2) {
			RoiManager.setGroup(2);
			SelectedKTs = SelectedKTs + 1;
			roiManager("deselect");
		} else {
			roiManager("deselect");
		}

	}

	function PreserveSelectedKTs() { 
	// Deletes ROIs which aren't of group = 2 and updates xPoints and yPoints with coords of remaining ROIs
		setBatchMode(true);
		
		// Delete group = 3 ROIs
		RoiManager.selectGroup(3);
		roiManager("delete");

		// Get x,y coords of remaining ROIs
		roiManager("List");
		xPoints = Table.getColumn("X");
		yPoints = Table.getColumn("Y");
		close(Table.title());

		// Adjust coordinates to find the center of each ROI
		for (i = 0; i < xPoints.length; i++) {
			xPoints[i] = xPoints[i] + size/2;
			yPoints[i] = yPoints[i] + size/2;
		}

		setBatchMode(false);
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

	}

}


macro "KT Quant Options [2]" {
	Dialog.create("KT Quant Options");
	Dialog.addChoice("Kinetochore channel", newArray("1", "2", "3", "4"), KinetochoreChannel);
	Dialog.addChoice("Selection method", newArray("Auto", "Manual"), SelectionMethod);
	Dialog.addChoice("Marker channel", newArray("1", "2", "3", "4"), MarkerChannel);
	Dialog.addNumber("Number of KTs", NumKTs);
	Dialog.addNumber("ROI diameter (px)", size);
	Dialog.addNumber("Background size (px)", BackgroundArea);
	Dialog.addCheckbox("Remove overlapping KTs", RemoveOverlaps);
	Dialog.show();

	KinetochoreChannel = parseInt(Dialog.getChoice());
	SelectionMethod = Dialog.getChoice();
	MarkerChannel = parseInt(Dialog.getChoice());
	NumKTs = Dialog.getNumber();
	size = Dialog.getNumber();
	BackgroundArea = Dialog.getNumber();
	RemoveOverlaps = Dialog.getCheckbox();
}