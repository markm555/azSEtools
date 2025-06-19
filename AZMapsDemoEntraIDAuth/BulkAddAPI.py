# This program requires Azure MAPS Data Contributor permission to work
import requests
import json
from urllib.parse import urlencode
from msal import ConfidentialClientApplication

# Azure AD and Azure Maps config
tenant_id = "your-tenant-id"
client_id = "your-client-id"
client_secret = "your-client-secret"
maps_client_id = "your-maps-client-id"  # From Azure Maps resource

authority = f"https://login.microsoftonline.com/{tenant_id}/v2.0"
scope = ["https://atlas.microsoft.com/.default"]
token_url = f"{authority}/oauth2/v2.0/token"

# Authenticate using MSAL
app = ConfidentialClientApplication(
    client_id,
    authority=authority,
    client_credential=client_secret
)

result = app.acquire_token_for_client(scopes=scope)
if "access_token" not in result:
    raise Exception("Token acquisition failed: " + json.dumps(result, indent=2))

access_token = result["access_token"]

# Addresses to geocode
addresses = [
    "10900 Stonelake Blvd, Austin, TX",
    "7000 George Bush, Irving, TX",
    "401 Sontera Blvd, San Antonio, TX",
    "750 Town and Country Blvd, Houston, TX"
]

# Create batch payload
batch_items = [{"addressLine": addr} for addr in addresses]
payload = {
    "batchItems": batch_items
}

# Submit batch geocode request
url = "https://atlas.microsoft.com/geocode:batch?api-version=2023-06-01"
headers = {
    "Authorization": f"Bearer {access_token}",
    "x-ms-client-id": maps_client_id,
    "Content-Type": "application/json"
}

response = requests.post(url, headers=headers, data=json.dumps(payload))

print("Batch Geocode Response:")
print(response.status_code)
print(response.text)
