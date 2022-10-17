// A tool for quantifying mitotic timings and outcomes
var DNAChan = 1;
var Description = "";

macro "Mitotic Timings Tool - C000D62D72D82D92Da2D43D53Db3Dc3D34Cf00D84C000Dd4D35Cf00D85C000Dd5D26Cf00D86C000De6D27Cf00D87C000De7D28Cf00D88C000De8D29Cf00D99C000De9D2aCf00DaaC000DeaD2bCf00DbbC000DdbD3cDdcD4dD5dDbdDcdD6eD7eD8eD9eDae" {
	
	items = newArray("Normal division", "Multipolar division", "Cell death", "Lagging chromosomes", "DNA bridge", "Imaging ended before division", "Off-axis division", "Other");
	
    // Get info about image, cursor position, and number of results
    ResultsCount = nResults;
    Title = getTitle();
    getCursorLoc(x, y, z, modifiers);
    getDimensions(width, height, channels, slices, frames);

    // Get starting timepoint
    NEBDslice = parseInt(GetTimePoint(getInfo("slice.label")));

    // Get Metaphase timepoint
    waitForUser("Move to metaphase timepoint");
    METAslice = parseInt(GetTimePoint(getInfo("slice.label")));

    // Get end timepoint
    waitForUser("Move to anaphase timepoint");
    ANAslice = parseInt(GetTimePoint(getInfo("slice.label")));

    Dialog.create("Cell fate");
    Dialog.addMessage("Description of cell fate");
    Dialog.addChoice("Category", items);
    Dialog.show();

	Description = Dialog.getChoice();

	if (Description == "Other") {
		Dialog.create("Other...");
   		Dialog.addMessage("Description of cell fate");
    	Dialog.addString("What happened?", "-");
    	Dialog.show();

		Description = Dialog.getString();
	}
    

    // Output results
    TabulateResults();

    // Add box to overlay during timepoints in which cell between NEBD and ANA
    GenerateOverlay();

    function GetTimePoint(SliceLabel) {
        starter = indexOf(SliceLabel, "t:");
        end = indexOf(SliceLabel, "/" + frames + "");
        sub = substring(SliceLabel, starter + 2, end);
        return sub;
    }

    function TabulateResults() {
        // Add line to results table concerning the cell of interest
        setResult("Image", ResultsCount, Title);
        setResult("x", ResultsCount, x);
        setResult("y", ResultsCount, y);
        setResult("NEBD", ResultsCount, NEBDslice);
        setResult("META", ResultsCount, METAslice);
        setResult("ANA", ResultsCount, ANAslice);
        setResult("NEBD-ANA (mins)", ResultsCount, (ANAslice - NEBDslice) * 5);
        setResult("NEBD-META (mins)", ResultsCount, (METAslice - NEBDslice) * 5);
        setResult("META-ANA (mins)", ResultsCount, (ANAslice - METAslice) * 5);
        setResult("Cell fate", ResultsCount, Description);
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
            Overlay.setPosition(DNAChan, 0, i);
        }

        run("Select None");
    }

}

macro "Mitotic Timings Tool Options" {
	DNAChan = getNumber("Select DNA channel", DNAChan);
}
