connect-azaccount
$loc = get-azlocation
# Define the variables for the connection string
$serverName = "<Your Server Name>"
$databaseName = "AzureRegions"
$username = "<UserName>"
$password = "<PassWord>"

# Construct the connection string for the master database
$connectionString = "Server=$serverName;Database=master;User Id=$username;Password=$password;"

# Query to create the database if it does not exist
$createDatabaseQuery = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$databaseName')
BEGIN
    CREATE DATABASE [$databaseName]
END
"@

# Query to create the table if it does not exist
$createTableQuery = @"
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AzureRegions')
BEGIN
    CREATE TABLE AzureRegions (
        id INT PRIMARY KEY IDENTITY(1,1),
        name NVARCHAR(255) NULL,
        displayName NVARCHAR(255) NULL,
        latitude FLOAT NULL,
        longitude FLOAT NULL,
        Location NVARCHAR(255) NULL,
        Type NVARCHAR(255) NULL,
        PhysicalLocation NVARCHAR(255) NULL,
        RegionType NVARCHAR(255) NULL,
        RegionCategory NVARCHAR(255) NULL,
        GeographyGroup NVARCHAR(255) NULL,
        PairedRegion NVARCHAR(255) NULL,
        Providers NVARCHAR(MAX) NULL
    )
END
"@

# Create an object to use with the SQL Client
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

# Open the connection to the master database
$connection.Open()

# Create an object to use with the connection to issue SQL Queries
$command = $connection.CreateCommand()

# Create the database
$command.CommandText = $createDatabaseQuery
$command.ExecuteNonQuery()

# Close the connection to the master database
$connection.Close()

# Construct the connection string for the new database
$connectionString = "Server=$serverName;Database=$databaseName;User Id=$username;Password=$password;"

# Create a new connection to the new database
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

# Open the connection to the new database
$connection.Open()

# Create a new command to use with the new database
$command = $connection.CreateCommand()

# Create the table
$command.CommandText = $createTableQuery
$command.ExecuteNonQuery()

# Insert data into the table
foreach ($region in $loc) {
    $name = if ($region.Location) { "'$($region.Location -replace "'", "''")'" } else { "NULL" }
    $displayName = if ($region.DisplayName) { "'$($region.DisplayName -replace "'", "''")'" } else { "NULL" }
    $latitude = if ($region.Latitude) { $region.Latitude } else { "NULL" }
    $longitude = if ($region.Longitude) { $region.Longitude } else { "NULL" }
    $location = if ($region.Location) { "'$($region.Location -replace "'", "''")'" } else { "NULL" }
    $type = if ($region.Type) { "'$($region.Type -replace "'", "''")'" } else { "NULL" }
    $physicalLocation = if ($region.PhysicalLocation) { "'$($region.PhysicalLocation -replace "'", "''")'" } else { "NULL" }
    $regionType = if ($region.RegionType) { "'$($region.RegionType -replace "'", "''")'" } else { "NULL" }
    $regionCategory = if ($region.RegionCategory) { "'$($region.RegionCategory -replace "'", "''")'" } else { "NULL" }
    $geographyGroup = if ($region.GeographyGroup) { "'$($region.GeographyGroup -replace "'", "''")'" } else { "NULL" }
    $pairedRegion = if ($region.PairedRegion.Name) { "'$($region.PairedRegion.Name -replace "'", "''")'" } else { "NULL" }
    $providers = if ($region.Providers) { "'$($region.Providers -replace "'", "''")'" } else { "NULL" }

    $query = @"
    INSERT INTO AzureRegions (
        name, displayName, latitude, longitude, Location, Type, PhysicalLocation, RegionType, RegionCategory, GeographyGroup, PairedRegion, Providers
    ) VALUES (
        $name, $displayName, $latitude, $longitude, $location, $type, $physicalLocation, $regionType, $regionCategory, $geographyGroup, $pairedRegion, $providers
    )
"@
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $command.ExecuteNonQuery()
}
# Close the connection to the new database
$connection.Close()


