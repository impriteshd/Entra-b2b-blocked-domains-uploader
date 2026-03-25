# Entra B2B Blocked Domains Uploader (Microsoft Graph + PowerShell)

Bulk upload a list of blocked domains into a Microsoft Entra **B2B Management Policy** using **Microsoft Graph (beta)** and **PowerShell**.

This is useful when you need to block invitations from a large set of external email domains.

---

## ✅ What this repo includes
- A PowerShell script to update `InvitationsAllowedAndBlockedDomainsPolicy.BlockedDomains`
- Sample domain input files (CSV/TXT)
- Built-in **25,000 character request size** validation to prevent Graph failures

---

## 📌 Graph API used

### Get policy list (to confirm policy exists / retrieve ID)
```http
GET https://graph.microsoft.com/beta/policies/b2bManagementPolicies
