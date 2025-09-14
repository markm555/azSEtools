section AzurePricing;

[Version = "1.0.0", DataSource.Kind = "AzurePricing", Publish = "AzurePricing.Publish"]

// Entry point
shared AzurePricing.Contents = AzurePricing.PricingData;

shared AzurePricing.PricingData = () =>
let
    BaseUrl = "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview",

    SPGetPage = (url as text) =>
        let
            response = Json.Document(Web.Contents(url, [Headers = [Accept = "application/json"]])),
            items = response[Items],
            nextPage = try response[NextPageLink] otherwise null
        in
            [Items = items, NextPage = nextPage],

    SPGetAllPages = (url as text, collected as list) =>
        let
            page = SPGetPage(url),
            newCollected = List.Combine({collected, page[Items]}),
            result = if page[NextPage] <> null then @SPGetAllPages(page[NextPage], newCollected) else newCollected
        in
            result,

    allItems = SPGetAllPages(BaseUrl, {}),

    itemsTable = 
        if List.IsEmpty(allItems) then 
            #table({}, {}) 
        else 
            let
                rawTable = Table.FromList(allItems, Splitter.SplitByNothing(), null, null),
                expanded = Table.ExpandRecordColumn(rawTable, "Column1",
                    {
                        "meterId", "meterName", "productId", "productName", "skuId", "skuName",
                        "serviceName", "serviceId", "retailPrice", "unitPrice", "currencyCode",
                        "armRegionName", "location", "effectiveStartDate", "type", "reservationTerm",
                        "savingsPlan"
                    },
                    {
                        "meterId", "meterName", "productId", "productName", "skuId", "skuName",
                        "serviceName", "serviceId", "retailPrice", "unitPrice", "currencyCode",
                        "armRegionName", "location", "effectiveStartDate", "type", "reservationTerm",
                        "savingsPlan"
                    }
                ),
                savingsExpanded = Table.ExpandListColumn(expanded, "savingsPlan"),
                savingsDetails = Table.ExpandRecordColumn(savingsExpanded, "savingsPlan", {"unitPrice", "term"}, {"savingsPlan_unitPrice", "savingsPlan_term"})
            in
                savingsDetails
in
    itemsTable;


AzurePricing = [
    Authentication = [
        Anonymous = []
    ],
    Label = "Azure Pricing - Be patient after clicking Connect, it can take a while to load all data",
    TestConnection = (dataSourcePath) => { AzurePricing.Contents }
];

// Publish metadata
AzurePricing.Publish = [
    Beta = false,
    Category = "Azure",
    ButtonText = { "Azure Pricing Data ... Connect to Azure pricing APIs" },
    LearnMoreUrl = "https://learn.microsoft.com/en-us/azure/cost-management-billing/",
    SourceImage = AzurePricing.Icons,
    SourceTypeImage = AzurePricing.Icons
];

// Icon definition
AzurePricing.Icons = [
    Icon16 = { Extension.Contents("AzurePricing16.png") },
    Icon32 = { Extension.Contents("AzurePricing32.png") }
];