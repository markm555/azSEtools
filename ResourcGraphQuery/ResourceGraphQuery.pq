let
    // Query the Azure Resource Graph
    Source = AzureResourceGraph.Query("Resources | where type =~ 'microsoft.azurearcdata/sqlserverinstances/databases'", null, null, null, [resultTruncated=null]),

    // Recursive function with depth limit
    ExpandColumnifExist = (table as table, columnName as text, prefix as text, depth as number) as table =>
        let
            ColumnExists = Table.HasColumns(table, columnName),
            ExpandedTable = if ColumnExists and depth > 0 then
                let
                    ColumnData = Table.Column(table, columnName),
                    ColumnIsRecord = List.NonNullCount(ColumnData) > 0 and ColumnData{0} is record,
                    ColumnNames = if ColumnIsRecord then Record.FieldNames(ColumnData{0}) else {},
                    PrefixedColumnNames = List.Transform(ColumnNames, each prefix & _),
                    ExpandedOnce = if ColumnIsRecord then
                        Table.ExpandRecordColumn(table, columnName, ColumnNames, PrefixedColumnNames)
                    else
                        table,
                    // Recursively expand nested columns with depth limit
                    ExpandedRecursively = List.Accumulate(PrefixedColumnNames, ExpandedOnce, (state, current) => 
                        if Table.HasColumns(state, current) and Table.Column(state, current){0} is record then
                            @ExpandColumnifExist(state, current, current & "_", depth - 1)
                        else
                            state
                    )
                in
                    ExpandedRecursively
            else
                table
        in
            ExpandedTable,

    // Function to detect and expand columns with embedded JSON with depth limit
    ExpandAllJsonColumns = (table as table, depth as number) as table =>
        let
            ColumnNames = Table.ColumnNames(table),
            ExpandedTable = List.Accumulate(ColumnNames, table, (state, current) =>
                let
                    ColumnData = Table.Column(state, current),
                    ColumnIsRecord = List.NonNullCount(ColumnData) > 0 and ColumnData{0} is record
                in
                    if ColumnIsRecord then
                        ExpandColumnifExist(state, current, current & "_", depth)
                    else
                        state
            )
        in
            ExpandedTable,

    // Apply the function to expand all JSON columns with a specified depth limit
    ExpandedTable = ExpandAllJsonColumns(Source, 3),
in
  ExpandedTable
