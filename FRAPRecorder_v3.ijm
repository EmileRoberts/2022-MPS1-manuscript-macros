// A macro for recording FRAP data from kinetochores using nearest-neighbour tracking

//Initialise global variables 
var xKTt0 = 0;
var yKTt0 = 0;
var xKT = 0;
var yKT = 0,
var Sigma = 2;
var xCoords = newArray();
var yCoords = newArray();
var JumpLimit = 3;
var ClosestIndex = 0;
var Closest = 0;
var ResultsCount = 0;
var CurrentFrame = 0;
var Prom = 5;
var KTDetected = true;
var Framerate = 3.8;
var KTMean = 0;
var KTArea = 0;
var CellMean = 0;
var CellArea = 0;
var CytoplasmMean = 0;
var CytoplasmArea = 0;
var BackgroundMean = 0;
var PreBleachPoints = 4;

// Get info about image and starting position of KT
Title = getTitle();
getDimensions(width, height, channels, slices, frames);
CleanUp();
run("Remove Overlay");

// Get start and end positions
GetInitialPosition();
GetFinalPosition();

// Get ROIs
GetCellROI();
GetCytoplasmROI();
GetBackgroundROI();


setBatchMode(true);
// Loop through each frame starting from the final frame
for (i = 0; i < frames; i++) {

	run("Select None");
	
    CurrentFrame = frames - i;

    // Keep track of number of results, temporarily store results
	ResultsCount = nResults;
	StoreResults();

    
    FindMaximaInFrame();
    GetMaximaPositions();
    FindClosestMaxima();

    if (KTDetected == false) {
        UpdatePositionByVelocity();
    }

	if (CurrentFrame == 1) {
		xKT = xKTt0;
		yKT = yKTt0;
	}

	
    AddOverlay();
	MeasureKT();
	MeasureROIs();

	RestoreResults();

	PopulateResults();
}

Table.sort("Frame");
CreatePlot();
CleanUp();
setBatchMode(false);

function GetInitialPosition() {
    // Get position of maxima in first frame based on user input
    Stack.setFrame(1);
    run("Enhance Contrast", "saturated=0.35");
    waitForUser("Please position cursor over KT of interest then press Enter");
    getCursorLoc(x, y, z, modifiers);

    xKT = x;
    yKT = y;

    FindMaximaInFrame();
    GetMaximaPositions();
    FindClosestMaxima();

    xKTt0 = xKT;
    yKTt0 = yKT;
}


function GetFinalPosition() {
    // Get position of maxima in last frame based on user input
    Stack.setFrame(frames);
    run("Enhance Contrast", "saturated=0.35");
    waitForUser("Please position cursor over KT of interest then press Enter");
    getCursorLoc(x, y, z, modifiers);
    xKT = x;
    yKT = y;

}


function FindMaximaInFrame() {
    // Duplicate current frame and find maxima

    // Duplicate CurrentFrame (FOI)
    selectImage(Title);
    Stack.setFrame(CurrentFrame);
    run("Duplicate...", "use");
    rename("FOI");

    run("Gaussian Blur...", "sigma=Sigma");

    run("Find Maxima...", "prominence=" + Prom + " output=List");

}

function GetMaximaPositions() {
    // Reads x,y coordinates (generated by FindMaximaInFrame) into xCoords and yCoords arrays

    // Check that objects have been found
    if (nResults == 0) {
        exit("No objects identified at time point " + CurrentFrame);
    }

    close("FOI");

    // Clear xCoords and yCoords arrays
    xCoords = newArray(nResults);
    yCoords = newArray(nResults);

    // Read coordinates into arrays
    for (j = 0; j < nResults; j++) {
        xCoords[j] = getResult("X", j);
        yCoords[j] = getResult("Y", j);
    }

    close("Results");
}

function FindClosestMaxima() {
    // Finds maxima closest to that in frame t+1, aborts if the distance is greater than JumpLim
    /*
     * Calculates distances between all objects found by FindCellPosition() and the
     * location of the cell in the previous frame (xCell, yCell)
     * Updates the coordinates of the cell to the closest particle
     * Outputs which ROI corresponds to the closest cell
     */


    Distances = newArray(xCoords.length);

    // For each object calculate the distance between it and the previous known location of the cell
    // Distances stored in Distances array
    for (j = 0; j < Distances.length; j++) {
        Distances[j] = DistanceCalc(xKT, yKT, xCoords[j], yCoords[j]);
    }

    // Find the shortest distance in the array and extract the index of it

    // Initialise first distance as the closest distance
    Closest = Distances[0];
    ClosestIndex = 0;

    // Compare each distance to the current Closest distance, update closest distance and ClosestIndex if smaller
    for (j = 0; j < Distances.length; j++) {
        if (Distances[j] < Closest) {
            Closest = Distances[j];
            ClosestIndex = j;
        }
    }

    // Check that the change in position isn't greater than the JumpLimit if cytokinesis has already occured
    if (Closest > JumpLimit) {
        KTDetected = false;
    } else {
    	// Update last known coordinates of KT
    	xKT = xCoords[ClosestIndex];
    	yKT = yCoords[ClosestIndex];
    }
}


function DistanceCalc(x1, y1, x2, y2) {
    //Function to output distances between two points (taken from http://imagej.1557.x6.nabble.com/distribution-analysis-nearest-neighbourhood-td5004447.html)
    //Calculate square of differences in x and y coords (so no negative numbers)
    sum_difference_squared = pow((x2 - x1), 2) + pow((y2 - y1), 2);
    //Square root answer to give scalar of distance
    output = pow(sum_difference_squared, 0.5);
    return output;
}

function AddOverlay() {
    // Draws oval overlay on current frame
    selectImage(Title);
    Stack.setFrame(CurrentFrame);
    makeOval(xKT - 4, yKT - 4, 8, 8);
    run("Add Selection...");
}

function UpdatePositionByVelocity() { 
// Calculate the velocity of the KT based on the last observed position and the starting position of the KT	
	xDelta = (xKT-xKTt0)/(CurrentFrame-1);
	yDelta = (yKT - yKTt0)/(CurrentFrame-1);
	
	xKT = xKT-xDelta;
	yKT = yKT-yDelta;
}

function MeasureKT() {
	 
	// Make a ROI based on current coordinates and make measurements
	run("Set Measurements...", "area mean redirect=None decimal=3");

	// Measure and read in to variables
    run("Measure");
    KTArea = getResult("Area", 0);
    KTMean = getResult("Mean", 0);

    close("Results");
	
}

function CleanUp() { 
	// Clear ROI manager and remove selections and overlay
	if (roiManager("count") > 0) {
        roiManager("deselect");
        roiManager("delete");
    }

	run("Select None");
}

function StoreResults() {
	if (ResultsCount != 0) {
		IJ.renameResults("CurrentResults");
	}
}

function RestoreResults() {
	 if (ResultsCount != 0) {
		IJ.renameResults("CurrentResults", "Results");
	}
}

function GetCellROI() {
	Stack.setFrame(PreBleachPoints+1);
	run("Enhance Contrast", "saturated=0.35");
	setTool("oval");
	waitForUser("Please trace cell outline");
	roiManager("add");
	run("Select None");
}

function GetCytoplasmROI() {
	setTool("brush");
	waitForUser("Please select cytoplasmic bleach spot");
	roiManager("add");
	run("Select None");
}

function GetBackgroundROI() {
	waitForUser("Please select background");
	roiManager("add");
	run("Select None");
}

function MeasureROIs() { 
// Measures mean and area of ROIs at each frame

	roiManager("select", 0);
	Stack.setFrame(CurrentFrame);
   	run("Measure");
	CellMean = getResult("Mean", 0);
	CellArea = getResult("Area", 0);
	close("Results");

	roiManager("select", 1);
	Stack.setFrame(CurrentFrame);
   	run("Measure");
	CytoplasmMean = getResult("Mean", 0);
	CytoplasmArea = getResult("Area", 0);
	close("Results");

	roiManager("select", 2);
	Stack.setFrame(CurrentFrame);
   	run("Measure");
	BackgroundMean = getResult("Mean", 0);
	close("Results");

}

function PopulateResults() { 
// Enters results from current frame into results table

	// Calculate corrected values
	KTMeanBack = KTMean - BackgroundMean;
	CytoMeanBack = CytoplasmMean - BackgroundMean;
	CellMeanBack = CellMean - BackgroundMean;
	KTDouble = KTMeanBack/CellMeanBack;
	CytoDouble = CytoMeanBack/CellMeanBack;

	// Update results table
	setResult("Frame", ResultsCount, CurrentFrame);
	setResult("Timepoint", ResultsCount, ((CurrentFrame-1)/Framerate) - (PreBleachPoints/Framerate));
	
	setResult("KT_Area", ResultsCount, KTArea);
	setResult("KT_Mean", ResultsCount, KTMean);

	setResult("Cytoplasm_Area", ResultsCount, CytoplasmArea);
	setResult("Cytoplasm_Mean", ResultsCount, CytoplasmMean);

	setResult("Cell_Area", ResultsCount, CellArea);
	setResult("Cell_Mean", ResultsCount, CellMean);

	setResult("Background_Mean", ResultsCount, BackgroundMean);

	setResult("KT_Mean_Back", ResultsCount, KTMeanBack);
	setResult("Cyto_Mean_Back", ResultsCount, CytoMeanBack);
	setResult("Cell_Mean_Back", ResultsCount, CellMeanBack);
	
	setResult("KT_Double", ResultsCount, KTDouble);
	setResult("Cyto_Double", ResultsCount, CytoDouble);
}

function CreatePlot() { 
// Plot KT double corrected measurements
	Plot.create("KT Intensity Double corrected", "Timepoint", "KT_Double");
	Plot.add("Circle", Table.getColumn("Timepoint", "Results"), Table.getColumn("KT_Double", "Results"));
	Plot.setStyle(0, "blue,#a0a0ff,1.0,Circle");
}