let
    	// Define parameters
    	//RangeEnd = DateTime.LocalNow(),
    	//RangeStart = Date.AddDays(RangeEnd, -1),

    	RangeStart = #datetime(2023,1, 1, 0, 0, 0),
    	RangeEnd = #datetime(2024, 1, 1, 0, 0, 0),

    	// Source data
    	Source = Sql.Database("db", "piawaredb"),
    	Table = Source{[Schema="dbo", Item="KDFW"]}[Data],

    	// Filter data using parameters
    	FilteredData = Table.SelectRows(Table, each [dt] >= RangeStart and [dt] < RangeEnd)
in
    	FilteredData

