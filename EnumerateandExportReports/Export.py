import requests
import time

# Define your Azure AD and Power BI API credentials
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_CLIENT_SECRET"
tenant_id = "YOUR_TENANT_ID"
resource = "https://analysis.windows.net/powerbi/api"
authority = f"https://login.microsoftonline.com/{tenant_id}/oauth2/token"

# Get the authentication token
body = {
    "grant_type": "client_credentials",
    "client_id": client_id,
    "client_secret": client_secret,
    "resource": resource
}

response = requests.post(authority, data=body)
token = response.json().get("access_token")

# Set the authorization header
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# Get all workspaces
workspaces_uri = "https://api.powerbi.com/v1.0/myorg/groups"
workspaces = requests.get(workspaces_uri, headers=headers).json()

# Enumerate all workspaces and their reports, and export each report as PDF
for workspace in workspaces.get("value", []):
    print(f"Workspace: {workspace['name']}")
    
    # Get all reports in the workspace
    reports_uri = f"https://api.powerbi.com/v1.0/myorg/groups/{workspace['id']}/reports"
    reports = requests.get(reports_uri, headers=headers).json()
    
    for report in reports.get("value", []):
        print(f"  Report: {report['name']}")
        
        # Export the report to PDF
        export_uri = f"https://api.powerbi.com/v1.0/myorg/groups/{workspace['id']}/reports/{report['id']}/ExportTo"
        export_body = {
            "format": "PDF"
        }
        
        export_response = requests.post(export_uri, headers=headers, json=export_body)
        export_id = export_response.json().get("id")
        
        # Check the export status
        status_uri = f"https://api.powerbi.com/v1.0/myorg/groups/{workspace['id']}/reports/{report['id']}/exports/{export_id}"
        while True:
            status_response = requests.get(status_uri, headers=headers).json()
            if status_response.get("status") == "Succeeded":
                break
            time.sleep(5)
        
        # Download the exported PDF file
        file_uri = f"https://api.powerbi.com/v1.0/myorg/groups/{workspace['id']}/reports/{report['id']}/exports/{export_id}/file"
        output_path = f"C:/Reports/{report['name']}.pdf"
        with requests.get(file_uri, headers=headers, stream=True) as r:
            r.raise_for_status()
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        
        print(f"  Report exported to: {output_path}")
