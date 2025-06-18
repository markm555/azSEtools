import requests
import urllib.parse
from msal import ConfidentialClientApplication
# you will need to install msal requests for this to work
# pip install msal requests

# Azure AD app registration
tenant_id = "<Your Tenant ID>"
client_id = "<Your Client ID>"
client_secret = "<Your Secret>"

maps_client_id = "<Your Azure Maps Client ID (not your SPN Client ID)>"

# Acquire token using MSAL
authority = f"https://login.microsoftonline.com/{tenant_id}"
app = ConfidentialClientApplication(
    client_id,
    authority=authority,
    client_credential=client_secret
)

scopes = ["https://atlas.microsoft.com/.default"]
result = app.acquire_token_for_client(scopes=scopes)
access_token = result["access_token"]

# Prepare address query
address = "500 W 2nd St, Austin, TX"
encoded_address = urllib.parse.quote(address)

# Build REST API request
url = f"https://atlas.microsoft.com/search/address/json?api-version=1.0&query={encoded_address}"

headers = {
    "Authorization": f"Bearer {access_token}",
    "x-ms-client-id": maps_client_id
}

response = requests.get(url, headers=headers)
print("Response:")
print(response.text)
