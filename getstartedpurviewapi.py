import requests
import json
from azure.identity import InteractiveBrowserCredential

# ========================
# CONFIG
# ========================
PURVIEW_ACCOUNT = "your-purview-account-name"
ATLAS_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"

# Scope for Purview (data plane)
SCOPE = "https://purview.azure.net/.default"

# ========================
# AUTH (interactive login)
# ========================
credential = InteractiveBrowserCredential()
token = credential.get_token(SCOPE).token

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# ========================
# SAMPLE BULK PAYLOAD
# ========================
# Example: create glossary terms or assets
# (Atlas entity format)

payload = {
    "entities": [
        {
            "typeName": "DataSet",
            "attributes": {
                "name": "demo_table_1",
                "qualifiedName": "demo_table_1@your_source",
                "description": "Demo table loaded via API"
            }
        },
        {
            "typeName": "DataSet",
            "attributes": {
                "name": "demo_table_2",
                "qualifiedName": "demo_table_2@your_source",
                "description": "Second demo table"
            }
        }
    ]
}

# ========================
# BULK INGEST CALL
# ========================
url = f"{ATLAS_ENDPOINT}/datamap/api/atlas/v2/entity/bulk"

response = requests.post(
    url,
    headers=headers,
    json=payload
)

# ========================
# OUTPUT
# ========================
print(f"Status: {response.status_code}")
print(json.dumps(response.json(), indent=2))
