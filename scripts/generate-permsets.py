#!/usr/bin/env python3
"""Generate permission sets for the Cert Game app."""
from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[1]
PS_DIR = ROOT / "force-app/main/default/permissionsets"
PSG_DIR = ROOT / "force-app/main/default/permissionsetgroups"
PS_DIR.mkdir(parents=True, exist_ok=True)
PSG_DIR.mkdir(parents=True, exist_ok=True)

ALL_OBJECTS = [
    "Certification_Exam__c", "Exam_Domain__c", "Question_Bank__c",
    "Trivia_Question__c", "Trivia_Answer_Choice__c", "Question_Citation__c",
    "Game_Session__c", "Game_Round__c", "Player__c", "Player_Answer__c",
    "Leaderboard_Snapshot__c", "Tournament__c", "Achievement__c",
    "Player_Achievement__c", "Study_Plan__c", "Tenant__c",
    "License_Event__c", "Usage_Metric__c", "Question_Generation_Job__c",
    "Slack_Event_Log__c", "Audit_Log__c", "App_Log__c",
]

def obj_perm(api, allowRead=True, allowCreate=False, allowEdit=False, allowDelete=False, modifyAll=False, viewAll=False):
    return dedent(f"""
    <objectPermissions>
        <object>{api}</object>
        <allowRead>{str(allowRead).lower()}</allowRead>
        <allowCreate>{str(allowCreate).lower()}</allowCreate>
        <allowEdit>{str(allowEdit).lower()}</allowEdit>
        <allowDelete>{str(allowDelete).lower()}</allowDelete>
        <modifyAllRecords>{str(modifyAll).lower()}</modifyAllRecords>
        <viewAllRecords>{str(viewAll).lower()}</viewAllRecords>
    </objectPermissions>""").rstrip()

def make_ps(name, label, description, obj_perms, has_license=False):
    body = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">',
        f'    <label>{label}</label>',
        f'    <description>{description}</description>',
        '    <hasActivationRequired>false</hasActivationRequired>',
    ]
    for p in obj_perms:
        body.append(p)
    body.append('</PermissionSet>')
    return "\n".join(body) + "\n"

# Full CRUD on everything + modifyAll
admin_perms = [obj_perm(o, True, True, True, True, True, True) for o in ALL_OBJECTS]

# Reviewer: read all content/gameplay, edit content objects, no delete
reviewer_read_edit = {"Certification_Exam__c", "Exam_Domain__c", "Question_Bank__c",
                      "Trivia_Question__c", "Trivia_Answer_Choice__c", "Question_Citation__c",
                      "Question_Generation_Job__c", "Audit_Log__c"}
reviewer_perms = []
for o in ALL_OBJECTS:
    if o in reviewer_read_edit:
        reviewer_perms.append(obj_perm(o, True, True, True, False, False, True))
    else:
        reviewer_perms.append(obj_perm(o, True, False, False, False, False, False))

# Player Manager: edit Player + Player_Answer + Player_Achievement
pm_edit = {"Player__c", "Player_Answer__c", "Player_Achievement__c", "Study_Plan__c"}
pm_perms = []
for o in ALL_OBJECTS:
    pm_perms.append(obj_perm(o, True, o in pm_edit, o in pm_edit, False, False, False))

# Tenant admin: billing
ta_edit = {"Tenant__c", "License_Event__c", "Usage_Metric__c"}
ta_perms = []
for o in ALL_OBJECTS:
    ta_perms.append(obj_perm(o, True, o in ta_edit, o in ta_edit, False, False, True))

# Read only
ro_perms = [obj_perm(o, True, False, False, False, False, False) for o in ALL_OBJECTS]

# Integration user: CRUD on gameplay + logs, no modifyAll
integ_full = {"Game_Session__c", "Game_Round__c", "Player__c", "Player_Answer__c",
              "Leaderboard_Snapshot__c", "Player_Achievement__c", "Slack_Event_Log__c",
              "Audit_Log__c", "App_Log__c", "License_Event__c", "Usage_Metric__c",
              "Question_Generation_Job__c", "Tenant__c", "Study_Plan__c"}
integ_perms = []
for o in ALL_OBJECTS:
    if o in integ_full:
        integ_perms.append(obj_perm(o, True, True, True, False, False, True))
    else:
        integ_perms.append(obj_perm(o, True, False, False, False, False, True))

permsets = {
    "Cert_Game_Admin": ("Cert Game Admin", "Full administration of Certification Trivia app.", admin_perms),
    "Cert_Game_Question_Reviewer": ("Cert Game Question Reviewer", "Reviews and publishes draft questions.", reviewer_perms),
    "Cert_Game_Player_Manager": ("Cert Game Player Manager", "Manages players and study plans.", pm_perms),
    "Cert_Game_Tenant_Admin": ("Cert Game Tenant Admin", "Manages tenant billing and seats.", ta_perms),
    "Cert_Game_Read_Only": ("Cert Game Read Only", "Read-only access to all Cert Game data.", ro_perms),
    "Cert_Game_Integration_User": ("Cert Game Integration User", "For Slack / Stripe callout user.", integ_perms),
}

for name, (label, desc, perms) in permsets.items():
    (PS_DIR / f"{name}.permissionset-meta.xml").write_text(
        make_ps(name, label, desc, perms))
    print("wrote ps", name)

# Permission set group
psg = dedent("""<?xml version="1.0" encoding="UTF-8"?>
<PermissionSetGroup xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Bundles all Certification Trivia admin permission sets.</description>
    <label>Cert Game All Admin</label>
    <permissionSets>Cert_Game_Admin</permissionSets>
    <permissionSets>Cert_Game_Question_Reviewer</permissionSets>
    <permissionSets>Cert_Game_Player_Manager</permissionSets>
    <permissionSets>Cert_Game_Tenant_Admin</permissionSets>
</PermissionSetGroup>
""")
(PSG_DIR / "Cert_Game_All_Admin.permissionsetgroup-meta.xml").write_text(psg)
print("wrote psg Cert_Game_All_Admin")
