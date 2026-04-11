# Microsoft Purview Data Map API – Fabric Example

## ⚠️ Important – Example Only

This repository contains a **worked example** that demonstrates how to call **Microsoft Purview Data Map (Atlas) REST APIs** using a **Service Principal**, after populating metadata via a **Microsoft Fabric scan**.

**This example is intentionally limited in scope.**

The script:
- ✅ Performs **read‑only operations only**
- ✅ **Displays API results to the console only**
- ❌ Does **not** create, update, or delete metadata
- ❌ Does **not** modify Purview configuration
- ❌ Is **not** intended as a production framework

This is designed for **learning, troubleshooting, demos, and reference**.

---

## License

MIT License

```text
MIT License

Copyright (c) 2026 Mark Moore

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Architecture

Microsoft Fabric (Tenant / Workspaces)
        |
        |  Fabric Scan (Managed Identity)
        v
Microsoft Purview Data Map
  Domain: Fabric
  Collection: <fabric-collection>
        |
        |  Data Map APIs (read‑only)
        v
PowerShell Script
(Service Principal authentication)

## What This Example Demonstrates

This single script demonstrates:

1. How to populate the **Microsoft Purview Data Map** using **Microsoft Fabric**
2. How to authenticate to Purview using a **Service Principal (client credentials flow)**
3. How to successfully call read‑only Purview Data Map APIs:
   - `types/typedefs`
   - `search/basic`
   - `lineage/{guid}`

---

## Critical Purview Concepts

### Domains vs Collections

- **Domains** organize assets (for example: `Fabric`, `On-Premises`)
- **Collections** are the **authorization boundary** for Purview Data Map APIs
- **Assets MUST exist in a collection** before API authorization succeeds

⚠️ If a collection contains **zero assets**, Purview Data Map APIs may return:

Even if RBAC permissions appear correct.

---

## Required Permissions
## To Resolve any 403 errors.
### 1. Azure Portal – Control Plane (Purview Resource)

Assign the following roles **on the Microsoft Purview account resource**:

| Principal | Role |
|--------|------|
| Service Principal | Owner *(or Contributor)* |
| Service Principal | Reader |

These permissions allow the Service Principal to be recognized by the Purview service.

---

### 2. Purview Studio – Data Map (Data Plane)

Assign the following role **at the collection level** where Fabric assets will be stored:

| Scope | Role |
|-----|------|
| Fabric → `<fabric-collection>` | **Purview Data Reader** |

⚠️ Admin roles alone are **not sufficient** for Data Map API access.

---

### 3. Microsoft Fabric Tenant Settings

In **Fabric Admin Portal → Tenant settings**, enable:

- ✅ **Service principals can use read-only admin APIs**
- ✅ **Enhanced admin API responses**

If required, configure a **security group** that includes the **Purview managed identity**.
