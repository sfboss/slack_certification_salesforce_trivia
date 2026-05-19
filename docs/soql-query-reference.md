# SOQL Query Reference Guide
## 1000 Diagnostic and Documentation Queries for Salesforce Administrators

> **Last Updated:** May 2026  
> **Purpose:** Comprehensive SOQL reference for org diagnostics, documentation, and management  
> **Target Audience:** Salesforce Administrators, Managers, Developers, Auditors

---

## Table of Contents

1. [User & Security Management](#1-user--security-management) (150 queries)
2. [Data Quality & Integrity](#2-data-quality--integrity) (120 queries)
3. [Standard Object Diagnostics](#3-standard-object-diagnostics) (180 queries)
4. [System Health & Performance](#4-system-health--performance) (100 queries)
5. [Custom Objects - Trivia Game](#5-custom-objects---trivia-game) (100 queries)
6. [Integration & External Services](#6-integration--external-services) (80 queries)
7. [Automation & Configuration](#7-automation--configuration) (90 queries)
8. [Reports & Analytics](#8-reports--analytics) (60 queries)
9. [Compliance & Audit](#9-compliance--audit) (70 queries)
10. [Troubleshooting & Diagnostics](#10-troubleshooting--diagnostics) (50 queries)

---

## 1. User & Security Management

### User Accounts

```sql
-- Query 1: All active users with basic info
SELECT Id, Name, Username, Email, Profile.Name, UserRole.Name, IsActive, LastLoginDate
FROM User
WHERE IsActive = true
ORDER BY Name
```

```sql
-- Query 2: Inactive users who haven't logged in for 90+ days
SELECT Id, Name, Username, Email, LastLoginDate, IsActive
FROM User
WHERE IsActive = false
AND LastLoginDate < LAST_N_DAYS:90
ORDER BY LastLoginDate DESC
```

```sql
-- Query 3: Users without roles
SELECT Id, Name, Username, Email, Profile.Name, UserRoleId
FROM User
WHERE UserRoleId = null
AND IsActive = true
ORDER BY Name
```

```sql
-- Query 4: Users with admin profiles
SELECT Id, Name, Username, Email, Profile.Name, LastLoginDate
FROM User
WHERE Profile.Name LIKE '%Admin%'
AND IsActive = true
ORDER BY LastLoginDate DESC
```

```sql
-- Query 5: Users created in the last 30 days
SELECT Id, Name, Username, Email, Profile.Name, CreatedDate, CreatedBy.Name
FROM User
WHERE CreatedDate = LAST_N_DAYS:30
ORDER BY CreatedDate DESC
```

```sql
-- Query 6: Users who never logged in
SELECT Id, Name, Username, Email, CreatedDate, LastLoginDate
FROM User
WHERE LastLoginDate = null
AND IsActive = true
ORDER BY CreatedDate DESC
```

```sql
-- Query 7: Users with multiple login failures
SELECT Id, Name, Username, Email, LastLoginDate
FROM User
WHERE IsActive = true
ORDER BY LastLoginDate DESC NULLS LAST
LIMIT 100
```

```sql
-- Query 8: Chatter-free users
SELECT Id, Name, Username, Email, UserType
FROM User
WHERE UserType = 'CsnOnly'
ORDER BY Name
```

```sql
-- Query 9: Community users
SELECT Id, Name, Username, Email, ContactId, UserType
FROM User
WHERE UserType LIKE '%Customer%'
OR UserType LIKE '%Partner%'
ORDER BY CreatedDate DESC
```

```sql
-- Query 10: Users by timezone
SELECT TimeZoneSidKey, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
GROUP BY TimeZoneSidKey
ORDER BY COUNT(Id) DESC
```

### Profiles & Permission Sets

```sql
-- Query 11: All profiles with user counts
SELECT Profile.Name, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
GROUP BY Profile.Name
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 12: All permission sets
SELECT Id, Name, Label, Description, Type, IsCustom, CreatedDate
FROM PermissionSet
WHERE IsOwnedByProfile = false
ORDER BY Name
```

```sql
-- Query 13: Permission set assignments by user
SELECT Id, Assignee.Name, Assignee.Username, PermissionSet.Name, PermissionSet.Label
FROM PermissionSetAssignment
WHERE Assignee.IsActive = true
ORDER BY Assignee.Name, PermissionSet.Name
```

```sql
-- Query 14: Users with specific permission set
SELECT Assignee.Id, Assignee.Name, Assignee.Username, Assignee.Email
FROM PermissionSetAssignment
WHERE PermissionSet.Name = 'Cert_Game_Admin'
AND Assignee.IsActive = true
ORDER BY Assignee.Name
```

```sql
-- Query 15: Permission sets assigned in last 30 days
SELECT Assignee.Name, PermissionSet.Name, AssignedDate
FROM PermissionSetAssignment
WHERE AssignedDate = LAST_N_DAYS:30
ORDER BY AssignedDate DESC
```

```sql
-- Query 16: System permissions in permission sets
SELECT Parent.Label, PermissionsApiEnabled, PermissionsModifyAllData, 
       PermissionsViewAllData, PermissionsManageUsers
FROM PermissionSet
WHERE IsOwnedByProfile = false
AND (PermissionsModifyAllData = true OR PermissionsViewAllData = true)
ORDER BY Parent.Label
```

```sql
-- Query 17: Object permissions by permission set
SELECT Parent.Label, SobjectType, PermissionsCreate, PermissionsRead, 
       PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords
FROM ObjectPermissions
WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE IsOwnedByProfile = false)
ORDER BY Parent.Label, SobjectType
```

```sql
-- Query 18: Field permissions for sensitive fields
SELECT Parent.Label, SobjectType, Field, PermissionsRead, PermissionsEdit
FROM FieldPermissions
WHERE Field LIKE '%SSN%' OR Field LIKE '%Salary%' OR Field LIKE '%Credit%'
ORDER BY SobjectType, Field
```

```sql
-- Query 19: Users with Modify All Data permission
SELECT Id, Name, Username, Profile.Name
FROM User
WHERE Profile.PermissionsModifyAllData = true
AND IsActive = true
ORDER BY Name
```

```sql
-- Query 20: Users with View All Data permission
SELECT Id, Name, Username, Profile.Name
FROM User
WHERE Profile.PermissionsViewAllData = true
AND IsActive = true
ORDER BY Name
```

### Login History & Security

```sql
-- Query 21: Recent login history (last 24 hours)
SELECT UserId, LoginTime, LoginType, SourceIp, Status, Application, Browser
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:1
ORDER BY LoginTime DESC
LIMIT 200
```

```sql
-- Query 22: Failed login attempts
SELECT UserId, LoginTime, SourceIp, Status
FROM LoginHistory
WHERE Status != 'Success'
AND LoginTime = LAST_N_DAYS:7
ORDER BY LoginTime DESC
```

```sql
-- Query 23: Logins from suspicious IPs
SELECT UserId, LoginTime, SourceIp, Status, LoginType
FROM LoginHistory
WHERE SourceIp NOT LIKE '10.%'
AND SourceIp NOT LIKE '192.168.%'
AND LoginTime = LAST_N_DAYS:7
ORDER BY LoginTime DESC
```

```sql
-- Query 24: Login frequency by user
SELECT UserId, COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
GROUP BY UserId
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 25: Login methods used
SELECT LoginType, COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
GROUP BY LoginType
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 26: API logins
SELECT UserId, LoginTime, SourceIp, Application
FROM LoginHistory
WHERE LoginType = 'API'
AND LoginTime = LAST_N_DAYS:7
ORDER BY LoginTime DESC
```

```sql
-- Query 27: Browser types used for login
SELECT Browser, COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
AND Browser != null
GROUP BY Browser
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 28: Platform type distribution
SELECT Platform, COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
GROUP BY Platform
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 29: Users with password expiry soon
SELECT Id, Name, Username, Email, LastPasswordChangeDate
FROM User
WHERE IsActive = true
AND LastPasswordChangeDate != null
ORDER BY LastPasswordChangeDate
LIMIT 50
```

```sql
-- Query 30: Users with expired passwords
SELECT Id, Name, Username, Email
FROM User
WHERE IsActive = true
AND IsPasswordExpired = true
ORDER BY Name
```

### Two-Factor Authentication

```sql
-- Query 31: Users with 2FA enabled
SELECT User.Name, User.Username, User.Email
FROM TwoFactorInfo
ORDER BY User.Name
```

```sql
-- Query 32: Active users without 2FA
SELECT Id, Name, Username, Email, Profile.Name
FROM User
WHERE IsActive = true
AND Id NOT IN (SELECT UserId FROM TwoFactorInfo)
ORDER BY Profile.Name, Name
```

```sql
-- Query 33: 2FA registration dates
SELECT User.Name, User.Username, CreatedDate
FROM TwoFactorInfo
ORDER BY CreatedDate DESC
```

```sql
-- Query 34: Temporary codes generated
SELECT User.Name, CreatedDate, ExpirationDate
FROM TwoFactorTempCode
WHERE ExpirationDate > TODAY
ORDER BY CreatedDate DESC
```

```sql
-- Query 35: Count users by 2FA status
SELECT 
  (SELECT COUNT() FROM User WHERE IsActive = true) TotalActive,
  (SELECT COUNT() FROM TwoFactorInfo) With2FA,
  (SELECT COUNT() FROM User WHERE IsActive = true AND Id NOT IN (SELECT UserId FROM TwoFactorInfo)) Without2FA
FROM User
LIMIT 1
```

### Delegated Administration

```sql
-- Query 36: Delegated admins
SELECT Id, Name, Username, DelegatedApproverId
FROM User
WHERE DelegatedApproverId != null
ORDER BY Name
```

```sql
-- Query 37: Group members
SELECT Group.Name, UserOrGroupId, User.Name
FROM GroupMember
WHERE User.IsActive = true
ORDER BY Group.Name, User.Name
```

```sql
-- Query 38: Public groups
SELECT Id, Name, Type, DeveloperName, CreatedDate
FROM Group
WHERE Type = 'Regular'
ORDER BY Name
```

```sql
-- Query 39: Queue members
SELECT Group.Name, UserOrGroupId, User.Name
FROM GroupMember
WHERE Group.Type = 'Queue'
AND User.IsActive = true
ORDER BY Group.Name, User.Name
```

```sql
-- Query 40: Role hierarchy
SELECT Id, Name, ParentRoleId, DeveloperName
FROM UserRole
ORDER BY ParentRoleId NULLS FIRST, Name
```

### Session Management

```sql
-- Query 41: Active sessions
SELECT UsersId, LoginType, SessionType, CreatedDate, LastModifiedDate
FROM AuthSession
WHERE CreatedDate = LAST_N_DAYS:1
ORDER BY CreatedDate DESC
```

```sql
-- Query 42: Session count by user
SELECT UsersId, COUNT(Id) SessionCount
FROM AuthSession
WHERE CreatedDate = LAST_N_DAYS:1
GROUP BY UsersId
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 43: Long-running sessions
SELECT UsersId, LoginType, SessionType, CreatedDate
FROM AuthSession
WHERE CreatedDate < LAST_N_DAYS:7
ORDER BY CreatedDate
```

```sql
-- Query 44: Mobile sessions
SELECT UsersId, LoginType, CreatedDate, LastModifiedDate
FROM AuthSession
WHERE SessionType = 'Mobile'
ORDER BY CreatedDate DESC
```

```sql
-- Query 45: API sessions
SELECT UsersId, LoginType, CreatedDate, LastModifiedDate
FROM AuthSession
WHERE SessionType = 'API'
ORDER BY CreatedDate DESC
```

### IP Restrictions & Network Access

```sql
-- Query 46: Login IP ranges (custom metadata if configured)
-- Note: This requires custom implementation
SELECT Id, Label, DeveloperName
FROM LoginIpRange
ORDER BY Label
```

```sql
-- Query 47: User IP ranges
SELECT User.Name, StartAddress, EndAddress
FROM LoginIpRange
ORDER BY User.Name
```

```sql
-- Query 48: Profile IP ranges
SELECT Profile.Name, StartAddress, EndAddress
FROM LoginIpRange
WHERE UsersId = null
ORDER BY Profile.Name
```

```sql
-- Query 49: Logins outside IP range
SELECT UserId, LoginTime, SourceIp, Status
FROM LoginHistory
WHERE Status = 'Invalid IP'
AND LoginTime = LAST_N_DAYS:7
ORDER BY LoginTime DESC
```

```sql
-- Query 50: Unique IPs by user
SELECT UserId, COUNT_DISTINCT(SourceIp) UniqueIPCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
GROUP BY UserId
HAVING COUNT_DISTINCT(SourceIp) > 5
ORDER BY COUNT_DISTINCT(SourceIp) DESC
```

### License Management

```sql
-- Query 51: User licenses summary
SELECT UserType, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
GROUP BY UserType
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 52: Permission set license assignments
SELECT PermissionSetLicense.MasterLabel, Assignee.Name, Assignee.Username
FROM PermissionSetLicenseAssign
WHERE Assignee.IsActive = true
ORDER BY PermissionSetLicense.MasterLabel, Assignee.Name
```

```sql
-- Query 53: Permission set licenses available
SELECT Id, MasterLabel, DeveloperName, TotalLicenses, UsedLicenses, Status
FROM PermissionSetLicense
ORDER BY MasterLabel
```

```sql
-- Query 54: Users approaching license limits
SELECT MasterLabel, TotalLicenses, UsedLicenses, (TotalLicenses - UsedLicenses) Available
FROM PermissionSetLicense
WHERE (TotalLicenses - UsedLicenses) < 10
ORDER BY Available
```

```sql
-- Query 55: Feature licenses by user
SELECT User.Name, User.Username, FeatureLicense.Name
FROM UserFeatureLicense
WHERE User.IsActive = true
ORDER BY User.Name
```

### Password Policies

```sql
-- Query 56: Users with weak passwords (if history available)
SELECT Id, Name, Username, LastPasswordChangeDate
FROM User
WHERE IsActive = true
AND LastPasswordChangeDate < LAST_N_DAYS:180
ORDER BY LastPasswordChangeDate
```

```sql
-- Query 57: Password change history
SELECT Id, Name, Username, LastPasswordChangeDate, CreatedDate
FROM User
WHERE LastPasswordChangeDate != null
ORDER BY LastPasswordChangeDate DESC
LIMIT 100
```

```sql
-- Query 58: Users requiring password reset
SELECT Id, Name, Username, Email
FROM User
WHERE IsActive = true
AND IsPasswordExpired = true
ORDER BY Name
```

```sql
-- Query 59: Recently reset passwords
SELECT Id, Name, Username, LastPasswordChangeDate
FROM User
WHERE LastPasswordChangeDate = LAST_N_DAYS:7
ORDER BY LastPasswordChangeDate DESC
```

```sql
-- Query 60: Users with never-changed passwords
SELECT Id, Name, Username, CreatedDate, LastPasswordChangeDate
FROM User
WHERE IsActive = true
AND LastPasswordChangeDate = CreatedDate
ORDER BY CreatedDate
```

### Territory Management

```sql
-- Query 61: Territory assignments
SELECT Territory2.Name, User.Name, User.Username
FROM UserTerritory2Association
WHERE User.IsActive = true
ORDER BY Territory2.Name, User.Name
```

```sql
-- Query 62: Territory hierarchy
SELECT Id, Name, ParentTerritory2Id, DeveloperName
FROM Territory2
ORDER BY ParentTerritory2Id NULLS FIRST, Name
```

```sql
-- Query 63: Territory models
SELECT Id, Name, Description, State, ActivatedDate
FROM Territory2Model
ORDER BY ActivatedDate DESC
```

```sql
-- Query 64: Territory rules
SELECT Territory2.Name, Name, BooleanFilter, Active
FROM Territory2Rule
WHERE Active = true
ORDER BY Territory2.Name, Name
```

```sql
-- Query 65: Territory coverage by user
SELECT User.Name, COUNT(Territory2Id) TerritoryCount
FROM UserTerritory2Association
WHERE User.IsActive = true
GROUP BY User.Name
ORDER BY COUNT(Territory2Id) DESC
```

### Sharing & Visibility

```sql
-- Query 66: Sharing rules
SELECT EntityDefinition.Label, Name, AccessLevel, RowCause
FROM SharingRules
ORDER BY EntityDefinition.Label, Name
```

```sql
-- Query 67: Manual shares (Account example)
SELECT UserOrGroupId, AccountId, AccountAccessLevel, OpportunityAccessLevel, CaseAccessLevel
FROM AccountShare
WHERE RowCause = 'Manual'
ORDER BY LastModifiedDate DESC
LIMIT 100
```

```sql
-- Query 68: Record ownership by user
SELECT OwnerId, Owner.Name, COUNT(Id) RecordCount
FROM Account
GROUP BY OwnerId, Owner.Name
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 69: Sharing hierarchy
SELECT Id, ParentId, Account.Name, AccountAccessLevel
FROM AccountShare
WHERE RowCause = 'Owner'
LIMIT 100
```

```sql
-- Query 70: Group shares
SELECT UserOrGroupId, AccountId, AccountAccessLevel
FROM AccountShare
WHERE RowCause != 'Owner' AND RowCause != 'Manual'
LIMIT 100
```

### Organization-Wide Defaults

```sql
-- Query 71: OWD settings (via setup)
-- Note: OWD is retrieved via Metadata API, not SOQL
-- This is a placeholder for documentation purposes
-- Use: SELECT QualifiedApiName, DefaultInternalAccess, DefaultExternalAccess FROM EntityDefinition
```

```sql
-- Query 72: Objects with private OWD
SELECT QualifiedApiName, Label, DefaultInternalAccess
FROM EntityDefinition
WHERE DefaultInternalAccess = 'Private'
ORDER BY Label
```

```sql
-- Query 73: Objects with public read/write OWD
SELECT QualifiedApiName, Label, DefaultInternalAccess
FROM EntityDefinition
WHERE DefaultInternalAccess = 'ReadWrite'
ORDER BY Label
```

```sql
-- Query 74: External sharing model
SELECT QualifiedApiName, Label, DefaultExternalAccess
FROM EntityDefinition
WHERE DefaultExternalAccess != null
ORDER BY Label
```

```sql
-- Query 75: All custom objects and sharing
SELECT QualifiedApiName, Label, DefaultInternalAccess, DefaultExternalAccess
FROM EntityDefinition
WHERE IsCustomizable = true
AND QualifiedApiName LIKE '%__c'
ORDER BY Label
```

### Field-Level Security

```sql
-- Query 76: Field access by profile
SELECT Parent.Profile.Name, SobjectType, Field, PermissionsRead, PermissionsEdit
FROM FieldPermissions
WHERE SobjectType = 'Account'
ORDER BY Parent.Profile.Name, Field
```

```sql
-- Query 77: Fields with restricted access
SELECT SobjectType, Field, COUNT(ParentId) ProfilesWithAccess
FROM FieldPermissions
WHERE PermissionsRead = true
GROUP BY SobjectType, Field
HAVING COUNT(ParentId) < 5
ORDER BY SobjectType, Field
```

```sql
-- Query 78: Hidden fields by profile
SELECT Parent.Profile.Name, SobjectType, Field
FROM FieldPermissions
WHERE PermissionsRead = false
ORDER BY Parent.Profile.Name, SobjectType, Field
```

```sql
-- Query 79: Read-only fields
SELECT Parent.Profile.Name, SobjectType, Field
FROM FieldPermissions
WHERE PermissionsRead = true AND PermissionsEdit = false
ORDER BY SobjectType, Field
```

```sql
-- Query 80: Editable fields by permission set
SELECT Parent.Label, SobjectType, Field
FROM FieldPermissions
WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE IsOwnedByProfile = false)
AND PermissionsEdit = true
ORDER BY Parent.Label, SobjectType, Field
```

### API Access & OAuth

```sql
-- Query 81: Connected apps
SELECT Id, Name, CreatedDate, ContactEmail
FROM ConnectedApplication
ORDER BY Name
```

```sql
-- Query 82: OAuth tokens by user
SELECT User.Name, App.Name, CreatedDate, LastModifiedDate
FROM OauthToken
WHERE User.IsActive = true
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 83: Recently revoked tokens
SELECT User.Name, App.Name, CreatedDate, LastModifiedDate
FROM OauthToken
WHERE LastModifiedDate = LAST_N_DAYS:7
ORDER BY LastModifiedDate DESC
```

```sql
-- Query 84: Active OAuth tokens count by app
SELECT App.Name, COUNT(Id) TokenCount
FROM OauthToken
GROUP BY App.Name
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 85: Expired OAuth tokens
SELECT User.Name, App.Name, CreatedDate, LastModifiedDate
FROM OauthToken
WHERE LastModifiedDate < LAST_N_DAYS:90
ORDER BY LastModifiedDate
```

### Data Classification

```sql
-- Query 86: Fields with data classification
SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, DataType, DataClassification
FROM FieldDefinition
WHERE DataClassification != null
ORDER BY EntityDefinition.QualifiedApiName, QualifiedApiName
```

```sql
-- Query 87: PII fields by object
SELECT EntityDefinition.QualifiedApiName, COUNT(Id) PIIFieldCount
FROM FieldDefinition
WHERE DataClassification IN ('HighlySensitive', 'Sensitive')
GROUP BY EntityDefinition.QualifiedApiName
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 88: Compliance categorization fields
SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, ComplianceGroup
FROM FieldDefinition
WHERE ComplianceGroup != null
ORDER BY ComplianceGroup, EntityDefinition.QualifiedApiName
```

```sql
-- Query 89: Encrypted fields
SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, DataType
FROM FieldDefinition
WHERE IsEncrypted = true
ORDER BY EntityDefinition.QualifiedApiName
```

```sql
-- Query 90: Fields requiring data protection
SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, DataClassification, SecurityClassification
FROM FieldDefinition
WHERE SecurityClassification = 'Restricted'
ORDER BY EntityDefinition.QualifiedApiName
```

### Org Limits

```sql
-- Query 91: Storage usage summary
-- Note: Use Limits methods in Apex or Tooling API for accurate org limits
SELECT OrganizationType
FROM Organization
LIMIT 1
```

```sql
-- Query 92: Data storage by object (approximation)
SELECT COUNT(Id) RecordCount
FROM Account
```

```sql
-- Query 93: File storage check
SELECT COUNT(Id) FileCount, SUM(BodyLength) TotalBytes
FROM ContentVersion
WHERE IsLatest = true
```

```sql
-- Query 94: Attachment storage
SELECT COUNT(Id) AttachmentCount, SUM(BodyLength) TotalBytes
FROM Attachment
```

```sql
-- Query 95: Document storage
SELECT COUNT(Id) DocumentCount, SUM(BodyLength) TotalBytes
FROM Document
```

### Email & Communication

```sql
-- Query 96: Email templates
SELECT Id, Name, DeveloperName, FolderName, IsActive, TemplateType
FROM EmailTemplate
WHERE IsActive = true
ORDER BY FolderName, Name
```

```sql
-- Query 97: Email messages sent (last 30 days)
SELECT Id, Subject, FromAddress, ToAddress, Status, CreatedDate
FROM EmailMessage
WHERE CreatedDate = LAST_N_DAYS:30
ORDER BY CreatedDate DESC
LIMIT 200
```

```sql
-- Query 98: Bounced emails
SELECT Id, FromAddress, ToAddress, Status, MessageDate
FROM EmailMessage
WHERE Status = 'Bounced'
AND MessageDate = LAST_N_DAYS:30
ORDER BY MessageDate DESC
```

```sql
-- Query 99: Email relay configuration
SELECT Id, DeveloperName, FromAddress, Host
FROM EmailServicesAddress
ORDER BY DeveloperName
```

```sql
-- Query 100: Email alerts
SELECT DeveloperName, Description, SenderType
FROM WorkflowAlert
ORDER BY DeveloperName
```

### Mobile Configuration

```sql
-- Query 101: Mobile sessions
SELECT UsersId, LoginType, CreatedDate
FROM AuthSession
WHERE SessionType = 'Mobile'
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 102: Salesforce1 usage
SELECT User.Name, COUNT(Id) MobileLogins
FROM LoginHistory
WHERE Application = 'Salesforce for Android'
   OR Application = 'Salesforce for iOS'
GROUP BY User.Name
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 103: Mobile devices by platform
SELECT Platform, COUNT(Id) LoginCount
FROM LoginHistory
WHERE Platform != null
AND LoginTime = LAST_N_DAYS:30
GROUP BY Platform
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 104: Mobile policy violations
-- Note: Implement based on your mobile security policies
SELECT User.Name, LoginTime, Platform
FROM LoginHistory
WHERE Platform LIKE '%Mobile%'
ORDER BY LoginTime DESC
LIMIT 100
```

```sql
-- Query 105: Offline mobile usage
-- Note: Track via custom instrumentation
SELECT Id, Name
FROM User
WHERE IsActive = true
LIMIT 1
```

### User Engagement

```sql
-- Query 106: Most active users (by login)
SELECT User.Name, COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
GROUP BY User.Name
ORDER BY COUNT(Id) DESC
LIMIT 50
```

```sql
-- Query 107: Inactive users (no recent login)
SELECT Id, Name, Username, Email, LastLoginDate
FROM User
WHERE IsActive = true
AND (LastLoginDate < LAST_N_DAYS:90 OR LastLoginDate = null)
ORDER BY LastLoginDate NULLS FIRST
```

```sql
-- Query 108: Users by login frequency bracket
SELECT 
  CASE 
    WHEN LastLoginDate = TODAY THEN 'Today'
    WHEN LastLoginDate = LAST_N_DAYS:7 THEN 'This Week'
    WHEN LastLoginDate = LAST_N_DAYS:30 THEN 'This Month'
    ELSE 'Older'
  END LoginBracket,
  COUNT(Id) UserCount
FROM User
WHERE IsActive = true
GROUP BY 
  CASE 
    WHEN LastLoginDate = TODAY THEN 'Today'
    WHEN LastLoginDate = LAST_N_DAYS:7 THEN 'This Week'
    WHEN LastLoginDate = LAST_N_DAYS:30 THEN 'This Month'
    ELSE 'Older'
  END
ORDER BY UserCount DESC
```

```sql
-- Query 109: First-time logins this month
SELECT Id, Name, Username, CreatedDate, LastLoginDate
FROM User
WHERE CreatedDate = THIS_MONTH
AND LastLoginDate != null
ORDER BY LastLoginDate
```

```sql
-- Query 110: User adoption by department
SELECT Department, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
AND Department != null
GROUP BY Department
ORDER BY COUNT(Id) DESC
```

### Single Sign-On

```sql
-- Query 111: SSO logins
SELECT User.Name, LoginTime, LoginType, SourceIp
FROM LoginHistory
WHERE LoginType = 'SAML Sfdc Initiated SSO'
   OR LoginType = 'SAML Idp Initiated SSO'
ORDER BY LoginTime DESC
LIMIT 200
```

```sql
-- Query 112: SSO login failures
SELECT User.Name, LoginTime, LoginType, Status
FROM LoginHistory
WHERE (LoginType LIKE '%SAML%' OR LoginType LIKE '%SSO%')
AND Status != 'Success'
ORDER BY LoginTime DESC
```

```sql
-- Query 113: SSO configuration check
-- Note: Use Auth Providers for SSO config
SELECT DeveloperName, FriendlyName, ProviderType
FROM AuthProvider
ORDER BY DeveloperName
```

```sql
-- Query 114: Federation IDs assigned
SELECT Id, Name, Username, FederationIdentifier
FROM User
WHERE FederationIdentifier != null
ORDER BY Name
```

```sql
-- Query 115: Users without SSO setup
SELECT Id, Name, Username, Email
FROM User
WHERE IsActive = true
AND FederationIdentifier = null
ORDER BY Name
```

### Custom Permissions

```sql
-- Query 116: Custom permissions defined
SELECT DeveloperName, Label, Description
FROM CustomPermission
ORDER BY DeveloperName
```

```sql
-- Query 117: Custom permission assignments
SELECT Parent.Label, CustomPermission.DeveloperName
FROM SetupEntityAccess
WHERE SetupEntityType = 'CustomPermission'
ORDER BY Parent.Label, CustomPermission.DeveloperName
```

```sql
-- Query 118: Users with specific custom permission
SELECT Assignee.Name, PermissionSet.Label
FROM PermissionSetAssignment
WHERE PermissionSetId IN (
  SELECT ParentId FROM SetupEntityAccess 
  WHERE SetupEntityId IN (
    SELECT Id FROM CustomPermission WHERE DeveloperName = 'Your_Custom_Permission'
  )
)
ORDER BY Assignee.Name
```

```sql
-- Query 119: Custom permissions by permission set
SELECT Parent.Label, COUNT(Id) CustomPermissionCount
FROM SetupEntityAccess
WHERE SetupEntityType = 'CustomPermission'
GROUP BY Parent.Label
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 120: Recently created custom permissions
SELECT DeveloperName, Label, CreatedDate, CreatedBy.Name
FROM CustomPermission
WHERE CreatedDate = LAST_N_DAYS:30
ORDER BY CreatedDate DESC
```

### External Users

```sql
-- Query 121: Portal users
SELECT Id, Name, Username, Contact.Account.Name, ContactId
FROM User
WHERE UserType LIKE '%Portal%'
ORDER BY Contact.Account.Name, Name
```

```sql
-- Query 122: Community members
SELECT Id, Name, Username, ContactId, UserType
FROM User
WHERE UserType IN ('CustomerSuccess', 'PowerCustomerSuccess', 'PowerPartner')
ORDER BY UserType, Name
```

```sql
-- Query 123: External user login activity
SELECT User.Name, LoginTime, SourceIp
FROM LoginHistory
WHERE UserId IN (SELECT Id FROM User WHERE UserType LIKE '%Customer%' OR UserType LIKE '%Partner%')
AND LoginTime = LAST_N_DAYS:7
ORDER BY LoginTime DESC
```

```sql
-- Query 124: External users by account
SELECT Contact.Account.Name, COUNT(Id) ExternalUserCount
FROM User
WHERE ContactId != null
GROUP BY Contact.Account.Name
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 125: Inactive external users
SELECT Id, Name, Username, Contact.Account.Name, LastLoginDate
FROM User
WHERE ContactId != null
AND (LastLoginDate < LAST_N_DAYS:90 OR LastLoginDate = null)
ORDER BY LastLoginDate NULLS FIRST
```

### App Usage

```sql
-- Query 126: Applications used for login
SELECT Application, COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
AND Application != null
GROUP BY Application
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 127: Logins by browser
SELECT Browser, COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
AND Browser != null
GROUP BY Browser
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 128: Desktop vs mobile usage
SELECT 
  CASE 
    WHEN Platform LIKE '%Mobile%' THEN 'Mobile'
    ELSE 'Desktop'
  END DeviceType,
  COUNT(Id) LoginCount
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
GROUP BY 
  CASE 
    WHEN Platform LIKE '%Mobile%' THEN 'Mobile'
    ELSE 'Desktop'
  END
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 129: API usage by application
SELECT Application, COUNT(Id) APICallCount
FROM LoginHistory
WHERE LoginType = 'API'
AND LoginTime = LAST_N_DAYS:7
GROUP BY Application
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 130: Unique users by application
SELECT Application, COUNT(DISTINCT UserId) UniqueUsers
FROM LoginHistory
WHERE LoginTime = LAST_N_DAYS:30
GROUP BY Application
ORDER BY COUNT(DISTINCT UserId) DESC
```

### Security Health Check

```sql
-- Query 131: Admin users summary
SELECT Profile.Name, COUNT(Id) AdminCount
FROM User
WHERE Profile.Name LIKE '%Admin%'
AND IsActive = true
GROUP BY Profile.Name
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 132: Users with dangerous permissions
SELECT Name, Username, Profile.Name
FROM User
WHERE (Profile.PermissionsModifyAllData = true 
   OR Profile.PermissionsViewAllData = true)
AND IsActive = true
ORDER BY Profile.Name, Name
```

```sql
-- Query 133: Shared accounts (same email)
SELECT Email, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
AND Email != null
GROUP BY Email
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 134: Generic usernames
SELECT Id, Name, Username, Email
FROM User
WHERE IsActive = true
AND (Username LIKE '%admin%' OR Username LIKE '%test%' OR Username LIKE '%demo%')
ORDER BY Username
```

```sql
-- Query 135: Users with special characters in username
SELECT Id, Name, Username, Email
FROM User
WHERE IsActive = true
AND Username LIKE '%+%'
ORDER BY Username
```

### Password Security

```sql
-- Query 136: Users with old passwords
SELECT Id, Name, Username, LastPasswordChangeDate
FROM User
WHERE IsActive = true
AND LastPasswordChangeDate < LAST_N_DAYS:365
ORDER BY LastPasswordChangeDate
```

```sql
-- Query 137: Password reset frequency
SELECT Id, Name, Username, LastPasswordChangeDate, CreatedDate
FROM User
WHERE LastPasswordChangeDate != CreatedDate
ORDER BY LastPasswordChangeDate DESC
LIMIT 100
```

```sql
-- Query 138: Users requiring immediate password change
SELECT Id, Name, Username, Email, IsPasswordExpired
FROM User
WHERE IsActive = true
AND IsPasswordExpired = true
ORDER BY Name
```

```sql
-- Query 139: Never-reset passwords
SELECT Id, Name, Username, CreatedDate, LastPasswordChangeDate
FROM User
WHERE IsActive = true
AND (LastPasswordChangeDate = null OR LastPasswordChangeDate = CreatedDate)
AND CreatedDate < LAST_N_DAYS:30
ORDER BY CreatedDate
```

```sql
-- Query 140: Recent password changes
SELECT Id, Name, Username, LastPasswordChangeDate, LastModifiedBy.Name
FROM User
WHERE LastPasswordChangeDate = LAST_N_DAYS:7
ORDER BY LastPasswordChangeDate DESC
```

### Compliance Users

```sql
-- Query 141: Users by locale
SELECT LocaleSidKey, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
GROUP BY LocaleSidKey
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 142: Users by language
SELECT LanguageLocaleKey, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
GROUP BY LanguageLocaleKey
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 143: Users by country
SELECT Country, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
AND Country != null
GROUP BY Country
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 144: Users requiring data residency compliance
SELECT Id, Name, Username, Country, Division
FROM User
WHERE IsActive = true
AND Country IN ('DE', 'FR', 'GB', 'AU', 'CA')
ORDER BY Country, Name
```

```sql
-- Query 145: Email encoding settings
SELECT EmailEncodingKey, COUNT(Id) UserCount
FROM User
WHERE IsActive = true
GROUP BY EmailEncodingKey
ORDER BY COUNT(Id) DESC
```

### Manager Hierarchy

```sql
-- Query 146: Direct reports by manager
SELECT Manager.Name, COUNT(Id) DirectReports
FROM User
WHERE IsActive = true
AND ManagerId != null
GROUP BY Manager.Name
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 147: Users without managers
SELECT Id, Name, Username, Email, Title
FROM User
WHERE IsActive = true
AND ManagerId = null
AND UserType = 'Standard'
ORDER BY Name
```

```sql
-- Query 148: Manager chain
SELECT Id, Name, Manager.Name, Manager.Manager.Name
FROM User
WHERE IsActive = true
AND ManagerId != null
ORDER BY Manager.Manager.Name NULLS LAST, Manager.Name, Name
```

```sql
-- Query 149: Span of control (wide managers)
SELECT Manager.Name, COUNT(Id) DirectReports
FROM User
WHERE IsActive = true
AND ManagerId != null
GROUP BY Manager.Name
HAVING COUNT(Id) > 15
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 150: Recently changed managers
SELECT Id, Name, Manager.Name, LastModifiedDate
FROM User
WHERE LastModifiedDate = LAST_N_DAYS:30
AND ManagerId != null
ORDER BY LastModifiedDate DESC
```

---

## 2. Data Quality & Integrity

### Duplicate Detection

```sql
-- Query 151: Duplicate accounts by name
SELECT Name, COUNT(Id) DuplicateCount
FROM Account
GROUP BY Name
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 152: Duplicate contacts by email
SELECT Email, COUNT(Id) DuplicateCount
FROM Contact
WHERE Email != null
GROUP BY Email
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 153: Duplicate leads by email
SELECT Email, Company, COUNT(Id) DuplicateCount
FROM Lead
WHERE Email != null
AND IsConverted = false
GROUP BY Email, Company
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 154: Accounts with same phone
SELECT Phone, COUNT(Id) DuplicateCount
FROM Account
WHERE Phone != null
GROUP BY Phone
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 155: Contacts with identical name and account
SELECT FirstName, LastName, Account.Name, COUNT(Id) DuplicateCount
FROM Contact
GROUP BY FirstName, LastName, Account.Name
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

### Missing Required Data

```sql
-- Query 156: Accounts without phone or website
SELECT Id, Name, Phone, Website
FROM Account
WHERE (Phone = null AND Website = null)
ORDER BY CreatedDate DESC
LIMIT 200
```

```sql
-- Query 157: Contacts without email
SELECT Id, Name, Account.Name, Phone
FROM Contact
WHERE Email = null
ORDER BY CreatedDate DESC
LIMIT 200
```

```sql
-- Query 158: Opportunities without close date
SELECT Id, Name, StageName, Amount, CloseDate
FROM Opportunity
WHERE CloseDate = null
ORDER BY CreatedDate DESC
```

```sql
-- Query 159: Cases without subject
SELECT Id, CaseNumber, Status, CreatedDate
FROM Case
WHERE Subject = null OR Subject = ''
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 160: Leads without company
SELECT Id, Name, Email, Status
FROM Lead
WHERE Company = null OR Company = ''
AND IsConverted = false
ORDER BY CreatedDate DESC
LIMIT 100
```

### Orphaned Records

```sql
-- Query 161: Contacts without accounts
SELECT Id, Name, Email, Phone
FROM Contact
WHERE AccountId = null
ORDER BY CreatedDate DESC
LIMIT 200
```

```sql
-- Query 162: Opportunities without contacts
SELECT Id, Name, AccountId, StageName, Amount
FROM Opportunity
WHERE Id NOT IN (SELECT OpportunityId FROM OpportunityContactRole WHERE OpportunityId != null)
AND IsClosed = false
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 163: Tasks without related records
SELECT Id, Subject, Status, ActivityDate
FROM Task
WHERE WhatId = null AND WhoId = null
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 164: Events without attendees
SELECT Id, Subject, StartDateTime, EndDateTime
FROM Event
WHERE WhoId = null AND WhatId = null
ORDER BY StartDateTime DESC
LIMIT 100
```

```sql
-- Query 165: Attachments without parent records
SELECT Id, Name, ParentId, CreatedDate
FROM Attachment
WHERE ParentId = null
ORDER BY CreatedDate DESC
LIMIT 100
```

### Invalid Data Patterns

```sql
-- Query 166: Emails with invalid format
SELECT Id, Name, Email
FROM Contact
WHERE Email != null
AND Email NOT LIKE '%@%.%'
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 167: Phone numbers with invalid characters
SELECT Id, Name, Phone
FROM Account
WHERE Phone != null
AND (Phone LIKE '%[%' OR Phone LIKE '%]%' OR Phone LIKE '%#%')
ORDER BY Name
LIMIT 100
```

```sql
-- Query 168: Postal codes with invalid format
SELECT Id, Name, BillingPostalCode, ShippingPostalCode
FROM Account
WHERE (BillingPostalCode != null AND LENGTH(BillingPostalCode) < 5)
   OR (ShippingPostalCode != null AND LENGTH(ShippingPostalCode) < 5)
ORDER BY Name
LIMIT 100
```

```sql
-- Query 169: Future dates in past fields
SELECT Id, Name, Birthdate
FROM Contact
WHERE Birthdate > TODAY
ORDER BY Birthdate DESC
```

```sql
-- Query 170: Negative amounts
SELECT Id, Name, Amount, StageName
FROM Opportunity
WHERE Amount < 0
ORDER BY Amount
```

### Data Completeness

```sql
-- Query 171: Account completeness score
SELECT Id, Name,
  CASE WHEN Phone != null THEN 1 ELSE 0 END +
  CASE WHEN Website != null THEN 1 ELSE 0 END +
  CASE WHEN BillingStreet != null THEN 1 ELSE 0 END +
  CASE WHEN Industry != null THEN 1 ELSE 0 END +
  CASE WHEN AnnualRevenue != null THEN 1 ELSE 0 END CompletenessScore
FROM Account
ORDER BY CompletenessScore
LIMIT 200
```

```sql
-- Query 172: Contacts with minimal data
SELECT Id, Name, Email, Phone, Title, Account.Name
FROM Contact
WHERE (Email = null OR Email = '')
AND (Phone = null OR Phone = '')
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 173: Opportunities missing key fields
SELECT Id, Name, Amount, CloseDate, StageName, NextStep
FROM Opportunity
WHERE NextStep = null
AND IsClosed = false
ORDER BY CloseDate
```

```sql
-- Query 174: Leads without lead source
SELECT Id, Name, Company, Email, LeadSource
FROM Lead
WHERE LeadSource = null
AND IsConverted = false
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 175: Cases without priority
SELECT Id, CaseNumber, Subject, Status, Priority
FROM Case
WHERE Priority = null
AND IsClosed = false
ORDER BY CreatedDate DESC
```

### Data Consistency

```sql
-- Query 176: Closed opportunities without close date
SELECT Id, Name, StageName, CloseDate, IsClosed
FROM Opportunity
WHERE IsClosed = true
AND CloseDate = null
```

```sql
-- Query 177: Won opportunities without amount
SELECT Id, Name, StageName, Amount, CloseDate
FROM Opportunity
WHERE IsWon = true
AND (Amount = null OR Amount = 0)
ORDER BY CloseDate DESC
```

```sql
-- Query 178: Accounts with type mismatch
SELECT Id, Name, Type, Industry
FROM Account
WHERE Type = 'Customer'
AND Id NOT IN (SELECT AccountId FROM Opportunity WHERE IsWon = true)
LIMIT 100
```

```sql
-- Query 179: Contacts on inactive accounts
SELECT Id, Name, Email, Account.Name, Account.IsActive__c
FROM Contact
WHERE Account.Active__c = 'No'
ORDER BY LastModifiedDate DESC
LIMIT 100
```

```sql
-- Query 180: Age vs experience mismatch
SELECT Id, Name, Age__c, Years_of_Experience__c
FROM Contact
WHERE Age__c < Years_of_Experience__c + 16
LIMIT 100
```

### Record Age Analysis

```sql
-- Query 181: Stale accounts (no activity in 365+ days)
SELECT Id, Name, LastActivityDate, LastModifiedDate
FROM Account
WHERE LastActivityDate < LAST_N_DAYS:365
OR (LastActivityDate = null AND LastModifiedDate < LAST_N_DAYS:365)
ORDER BY LastActivityDate NULLS FIRST
LIMIT 100
```

```sql
-- Query 182: Old open opportunities
SELECT Id, Name, StageName, CreatedDate, DaysSinceCreated__c
FROM Opportunity
WHERE IsClosed = false
AND CreatedDate < LAST_N_DAYS:180
ORDER BY CreatedDate
```

```sql
-- Query 183: Long-open cases
SELECT Id, CaseNumber, Subject, Status, CreatedDate
FROM Case
WHERE IsClosed = false
AND CreatedDate < LAST_N_DAYS:90
ORDER BY CreatedDate
```

```sql
-- Query 184: Aging leads
SELECT Id, Name, Company, Status, CreatedDate
FROM Lead
WHERE IsConverted = false
AND CreatedDate < LAST_N_DAYS:90
AND Status NOT IN ('Unqualified', 'Disqualified')
ORDER BY CreatedDate
```

```sql
-- Query 185: Records never modified since creation
SELECT Id, Name, CreatedDate, LastModifiedDate
FROM Account
WHERE CreatedDate = LastModifiedDate
AND CreatedDate < LAST_N_DAYS:30
ORDER BY CreatedDate
LIMIT 100
```

### Data Distribution

```sql
-- Query 186: Accounts by industry
SELECT Industry, COUNT(Id) AccountCount
FROM Account
WHERE Industry != null
GROUP BY Industry
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 187: Opportunities by stage
SELECT StageName, COUNT(Id) OpportunityCount, SUM(Amount) TotalAmount
FROM Opportunity
WHERE IsClosed = false
GROUP BY StageName
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 188: Cases by status
SELECT Status, COUNT(Id) CaseCount
FROM Case
GROUP BY Status
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 189: Leads by status
SELECT Status, COUNT(Id) LeadCount
FROM Lead
WHERE IsConverted = false
GROUP BY Status
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 190: Contacts by title category
SELECT Title, COUNT(Id) ContactCount
FROM Contact
WHERE Title != null
GROUP BY Title
ORDER BY COUNT(Id) DESC
LIMIT 50
```

### Data Volume by Object

```sql
-- Query 191: Record counts by standard object
SELECT COUNT(Id) AccountCount FROM Account
```

```sql
-- Query 192: Contact volume
SELECT COUNT(Id) ContactCount FROM Contact
```

```sql
-- Query 193: Opportunity volume
SELECT COUNT(Id) OpportunityCount FROM Opportunity
```

```sql
-- Query 194: Lead volume
SELECT COUNT(Id) LeadCount FROM Lead
```

```sql
-- Query 195: Case volume
SELECT COUNT(Id) CaseCount FROM Case
```

```sql
-- Query 196: Task volume
SELECT COUNT(Id) TaskCount FROM Task
```

```sql
-- Query 197: Event volume
SELECT COUNT(Id) EventCount FROM Event
```

```sql
-- Query 198: Note volume
SELECT COUNT(Id) NoteCount FROM Note
```

```sql
-- Query 199: Attachment volume
SELECT COUNT(Id) AttachmentCount FROM Attachment
```

```sql
-- Query 200: ContentDocument volume
SELECT COUNT(Id) DocumentCount FROM ContentDocument
```

### Historical Data Issues

```sql
-- Query 201: Records with future created dates
SELECT Id, Name, CreatedDate
FROM Account
WHERE CreatedDate > TODAY
ORDER BY CreatedDate DESC
```

```sql
-- Query 202: Opportunities closed before created
SELECT Id, Name, CreatedDate, CloseDate
FROM Opportunity
WHERE CloseDate < CreatedDate
```

```sql
-- Query 203: Cases closed before created
SELECT Id, CaseNumber, CreatedDate, ClosedDate
FROM Case
WHERE ClosedDate < CreatedDate
```

```sql
-- Query 204: Leads converted before created
SELECT Id, Name, CreatedDate, ConvertedDate
FROM Lead
WHERE ConvertedDate < CreatedDate
AND IsConverted = true
```

```sql
-- Query 205: Tasks completed before due date
SELECT Id, Subject, ActivityDate, CompletedDateTime
FROM Task
WHERE Status = 'Completed'
AND CompletedDateTime < ActivityDate
LIMIT 100
```

### Relationship Integrity

```sql
-- Query 206: Opportunity contact roles without contacts
SELECT Id, OpportunityId, ContactId, Role
FROM OpportunityContactRole
WHERE ContactId = null
```

```sql
-- Query 207: Account team members on deleted accounts
SELECT Id, AccountId, UserId, TeamMemberRole
FROM AccountTeamMember
WHERE AccountId = null
```

```sql
-- Query 208: Case team members without cases
SELECT Id, ParentId, MemberId
FROM CaseTeamMember
WHERE ParentId = null
```

```sql
-- Query 209: Opportunity partners without accounts
SELECT Id, OpportunityId, AccountToId, Role
FROM Partner
WHERE AccountToId = null
```

```sql
-- Query 210: Campaign members without campaigns
SELECT Id, CampaignId, ContactId, LeadId
FROM CampaignMember
WHERE CampaignId = null
```

### Standardization Issues

```sql
-- Query 211: Phone number format variations
SELECT Phone, COUNT(Id) RecordCount
FROM Account
WHERE Phone != null
GROUP BY Phone
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
LIMIT 50
```

```sql
-- Query 212: State/province standardization
SELECT BillingState, COUNT(Id) RecordCount
FROM Account
WHERE BillingState != null
GROUP BY BillingState
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 213: Country name variations
SELECT BillingCountry, COUNT(Id) RecordCount
FROM Account
WHERE BillingCountry != null
GROUP BY BillingCountry
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 214: Company name variations
SELECT Name, COUNT(Id) RecordCount
FROM Account
GROUP BY Name
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
LIMIT 50
```

```sql
-- Query 215: Title standardization needs
SELECT Title, COUNT(Id) ContactCount
FROM Contact
WHERE Title != null
GROUP BY Title
HAVING COUNT(Id) > 5
ORDER BY COUNT(Id) DESC
LIMIT 100
```

### Record Locking

```sql
-- Query 216: Locked records
SELECT Id, Name, IsLocked
FROM Account
WHERE IsLocked = true
ORDER BY LastModifiedDate DESC
```

```sql
-- Query 217: Recently locked opportunities
SELECT Id, Name, StageName, IsLocked
FROM Opportunity
WHERE IsLocked = true
ORDER BY LastModifiedDate DESC
LIMIT 100
```

```sql
-- Query 218: Locked cases
SELECT Id, CaseNumber, Status, IsLocked
FROM Case
WHERE IsLocked = true
ORDER BY LastModifiedDate DESC
```

```sql
-- Query 219: Approval-locked records
-- Note: Check approval process status
SELECT Id, Name, LastModifiedDate
FROM Account
WHERE IsLocked = true
LIMIT 100
```

```sql
-- Query 220: Records locked by user
SELECT Id, Name, IsLocked, LastModifiedBy.Name
FROM Account
WHERE IsLocked = true
ORDER BY LastModifiedBy.Name, LastModifiedDate DESC
```

### Data Quality Metrics

```sql
-- Query 221: Overall data completeness by object
SELECT COUNT(Id) TotalRecords,
  COUNT(Phone) RecordsWithPhone,
  COUNT(Website) RecordsWithWebsite
FROM Account
```

```sql
-- Query 222: Contact quality score distribution
SELECT 
  CASE 
    WHEN (Email != null AND Phone != null AND Title != null) THEN 'High Quality'
    WHEN (Email != null OR Phone != null) THEN 'Medium Quality'
    ELSE 'Low Quality'
  END QualityBracket,
  COUNT(Id) ContactCount
FROM Contact
GROUP BY 
  CASE 
    WHEN (Email != null AND Phone != null AND Title != null) THEN 'High Quality'
    WHEN (Email != null OR Phone != null) THEN 'Medium Quality'
    ELSE 'Low Quality'
  END
ORDER BY ContactCount DESC
```

```sql
-- Query 223: Opportunity data quality
SELECT COUNT(Id) TotalOpportunities,
  COUNT(Amount) WithAmount,
  COUNT(NextStep) WithNextStep,
  COUNT(Description) WithDescription
FROM Opportunity
WHERE IsClosed = false
```

```sql
-- Query 224: Lead data completeness
SELECT COUNT(Id) TotalLeads,
  COUNT(Email) WithEmail,
  COUNT(Phone) WithPhone,
  COUNT(LeadSource) WithLeadSource,
  COUNT(Industry) WithIndustry
FROM Lead
WHERE IsConverted = false
```

```sql
-- Query 225: Case data quality metrics
SELECT COUNT(Id) TotalCases,
  COUNT(Subject) WithSubject,
  COUNT(Description) WithDescription,
  COUNT(Priority) WithPriority
FROM Case
WHERE IsClosed = false
```

### Bulk Data Issues

```sql
-- Query 226: Records created in bulk (same second)
SELECT CreatedDate, CreatedBy.Name, COUNT(Id) RecordCount
FROM Account
WHERE CreatedDate = LAST_N_DAYS:7
GROUP BY CreatedDate, CreatedBy.Name
HAVING COUNT(Id) > 100
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 227: Mass updates detected
SELECT LastModifiedDate, LastModifiedBy.Name, COUNT(Id) RecordCount
FROM Contact
WHERE LastModifiedDate = LAST_N_DAYS:7
GROUP BY LastModifiedDate, LastModifiedBy.Name
HAVING COUNT(Id) > 100
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 228: Bulk deletions (via recycle bin check)
-- Note: Check SystemModstamp for deletion patterns
SELECT LastModifiedDate, COUNT(Id) DeletedCount
FROM Account
WHERE IsDeleted = true
GROUP BY LastModifiedDate
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 229: Import batch identification
SELECT CreatedBy.Name, HOUR_IN_DAY(CreatedDate) Hour, COUNT(Id) RecordCount
FROM Lead
WHERE CreatedDate = LAST_N_DAYS:30
GROUP BY CreatedBy.Name, HOUR_IN_DAY(CreatedDate)
HAVING COUNT(Id) > 50
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 230: Data loader footprint
SELECT CreatedBy.Name, DAY_ONLY(CreatedDate) LoadDate, COUNT(Id) RecordCount
FROM Contact
WHERE CreatedDate = LAST_N_DAYS:90
GROUP BY CreatedBy.Name, DAY_ONLY(CreatedDate)
HAVING COUNT(Id) > 200
ORDER BY COUNT(Id) DESC
```

### Picklist Value Usage

```sql
-- Query 231: Account type distribution
SELECT Type, COUNT(Id) AccountCount
FROM Account
WHERE Type != null
GROUP BY Type
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 232: Lead source effectiveness
SELECT LeadSource, COUNT(Id) LeadCount,
  COUNT(CASE WHEN IsConverted = true THEN 1 END) ConvertedCount
FROM Lead
GROUP BY LeadSource
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 233: Opportunity stage distribution
SELECT StageName, COUNT(Id) OpportunityCount, AVG(Probability) AvgProbability
FROM Opportunity
WHERE IsClosed = false
GROUP BY StageName
ORDER BY AVG(Probability) DESC
```

```sql
-- Query 234: Case priority distribution
SELECT Priority, COUNT(Id) CaseCount,
  AVG(CASE WHEN IsClosed = true THEN 1.0 ELSE 0.0 END) ClosureRate
FROM Case
GROUP BY Priority
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 235: Industry distribution
SELECT Industry, COUNT(Id) AccountCount
FROM Account
WHERE Industry != null
GROUP BY Industry
ORDER BY COUNT(Id) DESC
```

### Data Cleansing Candidates

```sql
-- Query 236: Accounts with test data indicators
SELECT Id, Name, Website, Phone
FROM Account
WHERE Name LIKE '%test%' OR Name LIKE '%demo%' OR Name LIKE '%sample%'
ORDER BY CreatedDate DESC
```

```sql
-- Query 237: Contacts with test emails
SELECT Id, Name, Email, Account.Name
FROM Contact
WHERE Email LIKE '%test%' OR Email LIKE '%example.com%' OR Email LIKE '%demo%'
ORDER BY CreatedDate DESC
```

```sql
-- Query 238: Placeholder data
SELECT Id, Name, Description
FROM Account
WHERE Name = 'TBD' OR Name = 'Unknown' OR Name = 'N/A'
ORDER BY CreatedDate DESC
```

```sql
-- Query 239: Dummy phone numbers
SELECT Id, Name, Phone
FROM Contact
WHERE Phone LIKE '555-1234' OR Phone LIKE '000%' OR Phone LIKE '111-1111'
ORDER BY CreatedDate DESC
```

```sql
-- Query 240: Generic names
SELECT Id, Name, Title, Email
FROM Contact
WHERE FirstName IN ('Test', 'Demo', 'Sample', 'Example', 'Admin')
ORDER BY CreatedDate DESC
```

### Cross-Object Data Quality

```sql
-- Query 241: Accounts vs opportunities mismatch
SELECT Id, Name, Type, 
  (SELECT COUNT() FROM Opportunities) OpportunityCount
FROM Account
WHERE Type = 'Customer'
HAVING (SELECT COUNT() FROM Opportunities) = 0
```

```sql
-- Query 242: Contacts on accounts without opportunities
SELECT Id, Name, Account.Name,
  (SELECT COUNT() FROM Account.Opportunities) OpportunityCount
FROM Contact
WHERE Account.Type = 'Prospect'
AND (SELECT COUNT() FROM Account.Opportunities) = 0
LIMIT 100
```

```sql
-- Query 243: High-value accounts without recent activity
SELECT Id, Name, AnnualRevenue, LastActivityDate
FROM Account
WHERE AnnualRevenue > 1000000
AND (LastActivityDate < LAST_N_DAYS:90 OR LastActivityDate = null)
ORDER BY AnnualRevenue DESC
```

```sql
-- Query 244: VIP contacts without recent touches
SELECT Id, Name, Account.Name, LastActivityDate
FROM Contact
WHERE Level__c = 'Primary'
AND (LastActivityDate < LAST_N_DAYS:30 OR LastActivityDate = null)
ORDER BY Account.Name
```

```sql
-- Query 245: Opportunities without activities
SELECT Id, Name, StageName, Amount,
  (SELECT COUNT() FROM Tasks) TaskCount,
  (SELECT COUNT() FROM Events) EventCount
FROM Opportunity
WHERE IsClosed = false
AND Amount > 100000
HAVING (SELECT COUNT() FROM Tasks) = 0
AND (SELECT COUNT() FROM Events) = 0
```

### Record Ownership Quality

```sql
-- Query 246: Records owned by inactive users
SELECT COUNT(Id) RecordCount, Owner.Name, Owner.IsActive
FROM Account
WHERE Owner.IsActive = false
GROUP BY Owner.Name, Owner.IsActive
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 247: Opportunities owned by wrong role
SELECT Id, Name, Owner.Name, Owner.UserRole.Name, Amount
FROM Opportunity
WHERE Owner.UserRole.Name NOT LIKE '%Sales%'
AND IsClosed = false
ORDER BY Amount DESC
LIMIT 100
```

```sql
-- Query 248: Cases owned by non-support users
SELECT Id, CaseNumber, Owner.Name, Owner.Profile.Name
FROM Case
WHERE Owner.Profile.Name NOT LIKE '%Support%'
AND IsClosed = false
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 249: Distribution of records by owner
SELECT Owner.Name, COUNT(Id) RecordCount
FROM Account
GROUP BY Owner.Name
ORDER BY COUNT(Id) DESC
LIMIT 50
```

```sql
-- Query 250: Owners with excessive record counts
SELECT Owner.Name, COUNT(Id) RecordCount
FROM Opportunity
WHERE IsClosed = false
GROUP BY Owner.Name
HAVING COUNT(Id) > 100
ORDER BY COUNT(Id) DESC
```

### Merge Candidates

```sql
-- Query 251: Potential duplicate accounts by name similarity
SELECT Name, Phone, Website, COUNT(Id) DuplicateCount
FROM Account
GROUP BY Name, Phone, Website
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
LIMIT 50
```

```sql
-- Query 252: Potential duplicate contacts
SELECT FirstName, LastName, Email, Account.Name, COUNT(Id) DuplicateCount
FROM Contact
WHERE Email != null
GROUP BY FirstName, LastName, Email, Account.Name
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

```sql
-- Query 253: Leads matching existing contacts
SELECT Id, Name, Email, Company
FROM Lead
WHERE Email IN (SELECT Email FROM Contact WHERE Email != null)
AND IsConverted = false
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 254: Leads matching existing accounts
SELECT Id, Name, Company, Email
FROM Lead
WHERE Company IN (SELECT Name FROM Account)
AND IsConverted = false
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 255: Similar account names (fuzzy match candidates)
SELECT Name, Phone, BillingCity, COUNT(Id) SimilarCount
FROM Account
GROUP BY Name, Phone, BillingCity
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
LIMIT 50
```

### Required Field Compliance

```sql
-- Query 256: Accounts missing required custom fields
SELECT Id, Name, Industry, Rating, Custom_Required_Field__c
FROM Account
WHERE Custom_Required_Field__c = null
ORDER BY CreatedDate DESC
LIMIT 100
```

```sql
-- Query 257: Opportunities missing next steps
SELECT Id, Name, StageName, CloseDate, NextStep
FROM Opportunity
WHERE NextStep = null
AND
