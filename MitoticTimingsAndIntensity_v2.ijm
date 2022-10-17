// A macro to record mitotic timings and signal at NEBD in a channel of interest

var DNAChan = 2;
var ChanToMeasure = 1;
var ChanToOutline = 1;

macro "Mitotic Timings Tool - C000D62D72D82D92Da2D43D53Db3Dc3D34Cf00D84C000Dd4D35Cf00D85C000Dd5D26Cf00D86C000De6D27Cf00D87C000De7D28Cf00D88C000De8D29Cf00D99C000De9D2aCf00DaaC000DeaD2bCf00DbbC000DdbD3cDdcD4dD5dDbdDcdD6eD7eD8eD9eDae" {

    // Get info about image, cursor position, and number of results
    ResultsCount = nResults;
    Title = getTitle();
    getCursorLoc(x, y, z, modifiers);
    getDimensions(width, height, channels, slices, frames);

    // Get starting timepoint
    NEBDslice = parseInt(GetTimePoint(getInfo("slice.label")));

    // Temporarily rename master results if they exist
    if (ResultsCount != 0) {
        IJ.renameResults("CurrentResults");
    }

    // Get cell outline from user based on specified channel
    setTool("freehand");
    Stack.setPosition(ChanToOutline, 1, NEBDslice);
    selectWindow(Title);
    run("Enhance Contrast", "saturated=0.35");
    waitForUser("Outline cell of interest");
    
    // Measure signal in specified channel
    Stack.setPosition(ChanToMeasure, 1, NEBDslice);
    run("Set Measurements...", "area mean redirect=None decimal=3");
    run("Measure");
    Mean = getResult("Mean", 0);
    Area = getResult("Area", 0);
    close("Results");
    run("Select None");

    // Get background area from user in specified channel
    Stack.setPosition(ChanToMeasure, 1, NEBDslice);
    run("Enhance Contrast", "saturated=0.35");
    selectWindow(Title);
    waitForUser("Select background");

    // Measure background
    run("Measure");
    BackgroundMean = getResult("Mean", 0);
    close("Results");
    run("Select None");

    // Restore master results if they exist
    if (ResultsCount != 0) {
        IJ.renameResults("CurrentResults", "Results");
    }


    // Get end timepoint
    Stack.setPosition(DNAChan, 1, NEBDslice);
    selectWindow(Title);
    waitForUser("Move to anaphase timepoint");
    ANAslice = parseInt(GetTimePoint(getInfo("slice.label")));

    // Output results
    TabulateResults();

    // Add box to overlay during timepoints in which cell between NEBD and ANA
    GenerateOverlay();

    selectWindow(Title);

    function GetTimePoint(SliceLabel) {
        starter = indexOf(SliceLabel, "t:");
        end = indexOf(SliceLabel, "/" + frames + "");
        trimmed = substring(SliceLabel, starter + 2, end);
        return trimmed;
    }

    function TabulateResults() {
        // Add line to results table concerning the cell of interest
        setResult("Image", ResultsCount, Title);
        setResult("x", ResultsCount, x);
        setResult("y", ResultsCount, y);
        setResult("NEBD", ResultsCount, NEBDslice);
        setResult("ANA", ResultsCount, ANAslice);
        setResult("NEBD-ANA (mins)", ResultsCount, (ANAslice - NEBDslice) * 5);
        setResult("Mean", ResultsCount, Mean);
        setResult("Area", ResultsCount, Area);
        setResult("Background Mean", ResultsCount, BackgroundMean);
        setResult("SignalAtNEBD", ResultsCount, Area * (Mean - BackgroundMean));
        updateResults();
    }

    function GenerateOverlay() {
        // Draw box indicating timings
        for (i = NEBDslice; i <= ANAslice; i++) {
            makeRectangle(x - 75, y - 75, 150, 150);
            if (i == NEBDslice) {
                Overlay.addSelection("green");
            } else if (i == ANAslice) {
                Overlay.addSelection("red");
            } else {
                Overlay.addSelection("yellow");
            }
            Overlay.setPosition(0, 0, i);
        }

        run("Select None");
    }

}

macro "Mitotic Timings Tool Options" {
	DNAChan = getNumber("Select DNA channel", DNAChan);
	ChanToMeasure = getNumber("Select channel to measure", ChanToMeasure);
	ChanToOutline = getNumber("Select channel to outline cell", ChanToOutline);
}


