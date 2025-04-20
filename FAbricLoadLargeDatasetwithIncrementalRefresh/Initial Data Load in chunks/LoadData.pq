let
    	// Define parameters
    	//RangeEnd = DateTime.LocalNow(),
    	//RangeStart = Date.AddDays(RangeEnd, -1),

        // This will pull back all days in the year 2023.
    	RangeStart = #datetime(2023,1, 1, 0, 0, 0),
    	RangeEnd = #datetime(2024, 1, 1, 0, 0, 0),

    	// Source data
    	Source = Sql.Database("<Your Server Name>", "<Your Database Name>"),
    	Table = Source{[Schema="dbo", Item="<Your Table Name"]}[Data],

    	// Filter data using parameters
    	FilteredData = Table.SelectRows(Table, each [<Your Date Time column>] >= RangeStart and [<Your Date Time column>] < RangeEnd)
in
    	FilteredData

