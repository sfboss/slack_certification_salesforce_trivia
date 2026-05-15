#!/usr/bin/env python3
"""Generate App_Setting__mdt fields and a single default record."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
F = ROOT / "force-app/main/default/objects/App_Setting__mdt/fields"
F.mkdir(parents=True, exist_ok=True)

FIELDS = [
    ("Default_Provider__c", "Default Provider", "Picklist",
     ["OpenAI", "Gemini", "Claude", "Manual", "Local"]),
    ("Default_Model__c", "Default Model", "Text", 80),
    ("Max_Questions_Per_Game__c", "Max Questions Per Game", "Number"),
    ("Max_Generation_Per_Day_Free__c", "Max Generation Per Day (Free)", "Number"),
    ("Max_Generation_Per_Day_Pro__c", "Max Generation Per Day (Pro)", "Number"),
    ("Max_Games_Per_Day_Free__c", "Max Games Per Day (Free)", "Number"),
    ("Slack_Signing_Secret_Named_Credential__c", "Slack Signing Secret Named Credential", "Text", 80),
    ("Slack_Bot_Named_Credential__c", "Slack Bot Named Credential", "Text", 80),
    ("Stripe_Named_Credential__c", "Stripe Named Credential", "Text", 80),
    ("OpenAI_Named_Credential__c", "OpenAI Named Credential", "Text", 80),
    ("Feature_Flag_Generation__c", "Feature Flag - Generation", "Checkbox"),
    ("Feature_Flag_Tournaments__c", "Feature Flag - Tournaments", "Checkbox"),
    ("Feature_Flag_Billing__c", "Feature Flag - Billing", "Checkbox"),
    ("Feature_Flag_Nudges__c", "Feature Flag - Nudges", "Checkbox"),
    ("Slack_Timestamp_Skew_Seconds__c", "Slack Timestamp Skew Seconds", "Number"),
]

def fxml(api, label, ftype, extra=None):
    parts = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">',
             f'    <fullName>{api}</fullName>',
             f'    <label>{label}</label>',
             f'    <type>{ftype}</type>']
    if ftype == "Text":
        parts.append(f'    <length>{extra or 80}</length>')
    elif ftype == "Number":
        parts.append('    <precision>12</precision>')
        parts.append('    <scale>0</scale>')
    elif ftype == "Checkbox":
        parts.append('    <defaultValue>false</defaultValue>')
    elif ftype == "Picklist":
        parts.append('    <valueSet>')
        parts.append('        <restricted>true</restricted>')
        parts.append('        <valueSetDefinition>')
        parts.append('            <sorted>false</sorted>')
        for v in extra:
            parts.append(f'            <value><fullName>{v}</fullName><label>{v}</label><default>false</default></value>')
        parts.append('        </valueSetDefinition>')
        parts.append('    </valueSet>')
    parts.append('</CustomField>\n')
    return "\n".join(parts)

for f in FIELDS:
    api, label, ftype = f[0], f[1], f[2]
    extra = f[3] if len(f) > 3 else None
    (F / f"{api}.field-meta.xml").write_text(fxml(api, label, ftype, extra))
    print("wrote", api)
