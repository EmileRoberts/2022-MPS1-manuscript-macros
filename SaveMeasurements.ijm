//A macro to save the results table
macro "SaveMeasurements [F6]" {

	//Get a name with which to save the results table
  	name = getString("Condition", "-");
  	//Get a directory in which to save the results table
	dir = getDirectory("choose where to save"); 
	//Save results table in chosen directory under choosen name as a csv file
	saveAs("Results",  dir + name + ".csv"); 

}