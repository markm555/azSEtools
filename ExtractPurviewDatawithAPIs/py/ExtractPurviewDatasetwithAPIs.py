"""
*****************************************************************************************************************************
****                                                                                                                     ****
****                                            Author & License Information                                             ****
****                                                                                                                     ****
****  Author:        Mark Moore                                                                                          ****
****  GitHub:        https://github.com/markm555                                                                          ****
****                                                                                                                     ****
****  Version History:                                                                                                   ****
****      v1.0.0  - Initial creation                                                                                     ****
****                                                                                                                     ****
****  License: MIT License                                                                                               ****
****                                                                                                                     ****
****  Copyright (c) 2026 Mark Moore                                                                                      ****
****                                                                                                                     ****
****  Permission is hereby granted, free of charge, to any person obtaining a copy                                       ****
****  of this software and associated documentation files (the "Software"), to deal                                      ****
****  in the Software without restriction, including without limitation the rights                                       ****
****  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell                                          ****
****  copies of the Software, and to permit persons to whom the Software is                                              ****
****  furnished to do so, subject to the following conditions:                                                           ****
****                                                                                                                     ****
****  The above copyright notice and this permission notice shall be included in                                         ****
****  all copies or substantial portions of the Software.                                                                ****
****                                                                                                                     ****
****  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR                                         ****
****  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,                                           ****
****  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE                                       ****
****  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER                                             ****
****  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,                                      ****
****  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN                                          ****
****  THE SOFTWARE.                                                                                                      ****
****                                                                                                                     ****
*****************************************************************************************************************************
"""

"""
*****************************************************************************************************************************
****                                                                                                                     ****
****                                   Service Principal (SPN) & Purview Configuration                                  ****
****                                                                                                                     ****
****  A Service Principal (SPN) represents an application identity in Microsoft Entra ID (Azure AD).                     ****
****  It is used for non-interactive authentication scenarios, such as automation, background jobs, and                  ****
****  service-to-service API calls.                                                                                      ****
****                                                                                                                     ****
****  IMPORTANT: The client secret is hard-coded in this script for demonstration purposes only.                         ****
****  In production, secrets should be stored securely (e.g., Azure Key Vault) and retrieved at runtime.                ****
****                                                                                                                     ****
*****************************************************************************************************************************
"""

"""
*****************************************************************************************************************************
****                                                                                                                     ****
****                                 Required Permissions for Microsoft Purview APIs                                    ****
****                                                                                                                     ****
****  Access to Microsoft Purview Data Map APIs requires permissions across multiple layers:                             ****
****   - Azure Portal (control plane): at least Reader on the Purview account resource                                   ****
****   - Purview Studio (data plane): Purview Data Reader on the Domain/Collection where assets reside                   ****
****                                                                                                                     ****
****  Collection scope matters. If assets are in child collections, the SPN must have access there,                      ****
****  or inheritance must be enabled.                                                                                    ****
****                                                                                                                     ****
****  Token behavior: permissions are evaluated when an access token is issued. After RBAC changes,                      ****
****  allow propagation time and acquire a NEW token.                                                                     ****
****                                                                                                                     ****
*****************************************************************************************************************************
"""

import json
import sys
from typing import Any, Dict, Optional, List

import requests
from azure.identity import ClientSecretCredential


# -------------------------------
# REQUIRED SETTINGS (EDIT THESE)
# -------------------------------
TENANT_ID = "<Tenant_ID>"
CLIENT_ID = "<Client_ID>"
CLIENT_SECRET = "<Client_Secret>"

PURVIEW_NAME = "<Your Purview Name>"  # e.g. "markm-purview"
PURVIEW_RESOURCE = "https://purview.azure.net"
PURVIEW_BASE_URL = f"https://{PURVIEW_NAME}.purview.azure.com"


# -------------------------------
# Get Access Token
# -------------------------------
def get_purview_access_token(tenant_id: str, client_id: str, client_secret: str) -> str:
    """
    *************************************************************************************************************************
    ****                                                                                                                 ****
    ****                                               Get Access Token                                                  ****
    ****  Access tokens are issued by Microsoft Entra ID (Azure AD) and are used to authenticate API calls.              ****
    ****  The token represents the identity and permissions of the calling application and is sent as:                   ****
    ****      Authorization: Bearer <token>                                                                              ****
    ****                                                                                                                 ****
    ****  Tokens are time-bound; default access token TTL is ~1 hour. After expiration, request a new token.             ****
    ****                                                                                                                 ****
    *************************************************************************************************************************
    """
    credential = ClientSecretCredential(tenant_id=tenant_id, client_id=client_id, client_secret=client_secret)
    token = credential.get_token(f"{PURVIEW_RESOURCE}/.default").token
    return token


# -------------------------------
# Invoke Purview REST API
# -------------------------------
def invoke_purview_api(
    purview_account_name: str,
    access_token: str,
    method: str,
    relative_path: str,
