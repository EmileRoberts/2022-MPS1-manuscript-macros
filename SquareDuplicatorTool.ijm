// Set default values for Square duplicator tool
// size = length of square in px
// AllTimepoints stores if the user should specify timepoints
var size = 250;
var AllTimepoints = true;

// Trigger main macro with single click
macro "Square Duplicator Tool - C000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccD00D01D02D03D04D05D06D07D08D09D0aD0bD0cD0dD0eD0fD10D1fD20D26D27D28D29D2fD30D35D36D39D3aD3bD3cD3fD40D44D45D4cD4dD4fD50D53D54D58D59D5aD5dD5fD60D63D68D69D6aD6dD6fD70D72D73D78D79D7aD7dD7fD80D82D8cD8dD8fD90D92D9cD9fDa0Da2DacDafDb0Db2DbcDbfDc0Dc2Dc3Dc5Dc6Dc7Dc8Dc9DcaDcbDccDcfDd0Dd3Dd4Dd5DdfDe0DefDf0Df1Df2Df3Df4Df5Df6Df7Df8Df9DfaDfbDfcDfdDfeDffCcccCdddCeeeCfffD11D12D13D14D15D16D17D18D19D1aD1bD1cD1dD1eD21D22D23D24D25D2aD2bD2cD2dD2eD31D32D33D34D37D38D3dD3eD41D42D43D46D47D48D49D4aD4bD4eD51D52D55D56D57D5bD5cD5eD61D62D64D65D66D67D6bD6cD6eD71D74D75D76D77D7bD7cD7eD81D83D84D85D86D87D88D89D8aD8bD8eD91D93D94D95D96D97D98D99D9aD9bD9dD9eDa1Da3Da4Da5Da6Da7Da8Da9DaaDabDadDaeDb1Db3Db4Db5Db6Db7Db8Db9DbaDbbDbdDbeDc1Dc4DcdDceDd1Dd2Dd6Dd7Dd8Dd9DdaDdbDdcDddDdeDe1De2De3De4De5De6De7De8De9DeaDebDecDedDee" { 
	
	// Find where the cursor is   
	getCursorLoc(x, y, z, flags);

	// Set origin for drawing rectangle based on cursor position and size of square
	x = x - size/2;
	y = y - size/2;

	// Make rectangular selection at calculated origin of specified size
	makeRectangle(x, y, size, size);

	// if else statement for selecting all or a range of timepoints
	if (AllTimepoints == true) {
		// Duplicate selected region (all stacks and channels)
		run("Duplicate...", "duplicate");
	} else {
		// Get desired slices from user
		Dialog.create("Select timepoints");
		Dialog.addNumber("Start", 1);
		Dialog.addNumber("End", 2);
		Dialog.show();

		Start = Dialog.getNumber();
		End = Dialog.getNumber();
		
		run("Duplicate...", "duplicate frames=Start-End");

	}
   
}


// Trigger settings macro with double click
macro "Square Duplicator Tool Options" {
	size = getNumber("Size: ", size);
	AllTimepoints = getBoolean("Duplicate all timepoints?");
}