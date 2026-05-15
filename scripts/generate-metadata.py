#!/usr/bin/env python3
"""
Generate Salesforce custom object metadata for the Cert Game Slack Manager.
Run once: python3 scripts/generate-metadata.py
Idempotent — overwrites existing object-meta.xml + field-meta.xml files.
"""
from __future__ import annotations

import os
from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[1]
OBJECTS_DIR = ROOT / "force-app" / "main" / "default" / "objects"

API_VERSION = "60.0"


def obj_xml(label: str, plural: str, description: str = "", external_id_field: str | None = None, name_type: str = "Text") -> str:
    name_field = (
        '<nameField>\n'
        f'        <label>{label} Name</label>\n'
        '        <type>Text</type>\n'
        '    </nameField>'
        if name_type == "Text"
        else (
            '<nameField>\n'
            f'        <label>{label} Name</label>\n'
            '        <displayFormat>{0000}</displayFormat>\n'
            '        <type>AutoNumber</type>\n'
            '    </nameField>'
        )
    )
    return dedent(f"""<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <description>{description}</description>
    <enableActivities>false</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>true</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <label>{label}</label>
    {name_field}
    <pluralLabel>{plural}</pluralLabel>
    <sharingModel>ReadWrite</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
""")


def field(api: str, label: str, ftype: str, **opts) -> tuple[str, str]:
    """Return (filename, xml) for a custom field."""
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">',
        f'    <fullName>{api}</fullName>',
        f'    <label>{label}</label>',
        f'    <type>{ftype}</type>',
    ]
    if opts.get("required"):
        parts.append('    <required>true</required>')
    if opts.get("unique"):
        parts.append('    <unique>true</unique>')
    if opts.get("external_id"):
        parts.append('    <externalId>true</externalId>')
    if "length" in opts:
        parts.append(f'    <length>{opts["length"]}</length>')
    if ftype == "Text":
        parts.append(f'    <length>{opts.get("length", 255)}</length>')
    if ftype == "LongTextArea":
        parts.append(f'    <length>{opts.get("length", 32768)}</length>')
        parts.append(f'    <visibleLines>{opts.get("visible_lines", 5)}</visibleLines>')
    if ftype == "TextArea":
        pass
    if ftype == "Number":
        parts.append(f'    <precision>{opts.get("precision", 18)}</precision>')
        parts.append(f'    <scale>{opts.get("scale", 0)}</scale>')
    if ftype == "Percent":
        parts.append(f'    <precision>{opts.get("precision", 5)}</precision>')
        parts.append(f'    <scale>{opts.get("scale", 2)}</scale>')
    if ftype == "Currency":
        parts.append(f'    <precision>{opts.get("precision", 18)}</precision>')
        parts.append(f'    <scale>{opts.get("scale", 2)}</scale>')
    if ftype == "Checkbox":
        parts.append(f'    <defaultValue>{str(opts.get("default", False)).lower()}</defaultValue>')
    if ftype == "Picklist":
        values = opts["values"]
        parts.append('    <valueSet>')
        parts.append('        <restricted>true</restricted>')
        parts.append('        <valueSetDefinition>')
        parts.append('            <sorted>false</sorted>')
        for v in values:
            parts.append('            <value>')
            parts.append(f'                <fullName>{v}</fullName>')
            parts.append(f'                <label>{v}</label>')
            parts.append('                <default>false</default>')
            parts.append('            </value>')
        parts.append('        </valueSetDefinition>')
        parts.append('    </valueSet>')
    if ftype in ("Lookup", "MasterDetail"):
        parts.append(f'    <referenceTo>{opts["reference_to"]}</referenceTo>')
        parts.append(f'    <relationshipName>{opts["relationship_name"]}</relationshipName>')
        parts.append(f'    <relationshipLabel>{opts.get("relationship_label", label)}</relationshipLabel>')
        if ftype == "MasterDetail":
            parts.append('    <reparentableMasterDetail>false</reparentableMasterDetail>')
            parts.append('    <writeRequiresMasterRead>false</writeRequiresMasterRead>')
        parts.append('    <deleteConstraint>SetNull</deleteConstraint>' if ftype == "Lookup" else '')
    if ftype == "Url":
        pass
    if ftype == "Email":
        pass
    if ftype == "DateTime" or ftype == "Date":
        pass
    if "formula" in opts:
        parts.append(f'    <formula>{opts["formula"]}</formula>')
        parts.append('    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>')
    parts.append('</CustomField>')
    return f"{api}.field-meta.xml", "\n".join(p for p in parts if p) + "\n"


# Object definitions: name -> (label, plural, description, fields[])
OBJECTS: dict[str, dict] = {
    "Certification_Exam__c": dict(
        label="Certification Exam", plural="Certification Exams",
        description="A vendor certification players can study for.",
        fields=[
            ("Vendor__c", "Vendor", "Text", {}),
            ("Certification_Code__c", "Certification Code", "Text", dict(external_id=True, unique=True, length=80)),
            ("Role_Family__c", "Role Family", "Text", {}),
            ("Difficulty__c", "Difficulty", "Picklist", dict(values=["Beginner", "Intermediate", "Advanced", "Expert"])),
            ("Description__c", "Description", "LongTextArea", dict(length=32768, visible_lines=4)),
            ("Official_Exam_Guide_URL__c", "Official Exam Guide URL", "Url", {}),
            ("Active__c", "Active", "Checkbox", dict(default=True)),
            ("Default_Timer_Seconds__c", "Default Timer Seconds", "Number", dict(precision=4, scale=0)),
            ("Passing_Score_Percent__c", "Passing Score Percent", "Percent", {}),
            ("Premium_Only__c", "Premium Only", "Checkbox", dict(default=False)),
            ("Icon_Emoji__c", "Icon Emoji", "Text", dict(length=10)),
        ],
    ),
    "Exam_Domain__c": dict(
        label="Exam Domain", plural="Exam Domains",
        description="A weighted domain inside a certification exam.",
        fields=[
            ("Certification_Exam__c", "Certification Exam", "Lookup",
             dict(reference_to="Certification_Exam__c", relationship_name="Domains", required=True)),
            ("Weight_Percent__c", "Weight Percent", "Percent", {}),
            ("Domain_Order__c", "Domain Order", "Number", dict(precision=3, scale=0)),
            ("Official_Objective_Text__c", "Official Objective Text", "LongTextArea", {}),
        ],
    ),
    "Question_Bank__c": dict(
        label="Question Bank", plural="Question Banks",
        description="A versioned set of trivia questions for an exam.",
        fields=[
            ("Certification_Exam__c", "Certification Exam", "Lookup",
             dict(reference_to="Certification_Exam__c", relationship_name="Question_Banks", required=True)),
            ("Source_Type__c", "Source Type", "Picklist",
             dict(values=["Manual", "Generated", "Imported", "OfficialNotesDerived"])),
            ("Status__c", "Status", "Picklist",
             dict(values=["Draft", "Review", "Published", "Retired"])),
            ("Version__c", "Version", "Text", dict(length=20)),
            ("Generated_By_Model__c", "Generated By Model", "Text", dict(length=80)),
            ("Prompt_Version__c", "Prompt Version", "Text", dict(length=40)),
            ("Created_From_File__c", "Created From File", "Text", dict(length=255)),
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="Question_Banks")),
            ("Premium__c", "Premium", "Checkbox", dict(default=False)),
            ("External_Id__c", "External Id", "Text", dict(external_id=True, unique=True, length=80)),
        ],
    ),
    "Trivia_Question__c": dict(
        label="Trivia Question", plural="Trivia Questions",
        description="A single trivia question. Inert until Status = Published.",
        fields=[
            ("Question_Bank__c", "Question Bank", "Lookup",
             dict(reference_to="Question_Bank__c", relationship_name="Questions")),
            ("Certification_Exam__c", "Certification Exam", "Lookup",
             dict(reference_to="Certification_Exam__c", relationship_name="Questions", required=True)),
            ("Exam_Domain__c", "Exam Domain", "Lookup",
             dict(reference_to="Exam_Domain__c", relationship_name="Questions")),
            ("Question_Text__c", "Question Text", "LongTextArea", dict(visible_lines=4)),
            ("Scenario_Text__c", "Scenario Text", "LongTextArea", dict(visible_lines=4)),
            ("Question_Type__c", "Question Type", "Picklist",
             dict(values=["Single Select", "Multi Select", "True False"])),
            ("Difficulty__c", "Difficulty", "Picklist",
             dict(values=["Beginner", "Intermediate", "Advanced", "Expert"])),
            ("Status__c", "Status", "Picklist",
             dict(values=["Draft", "Reviewed", "Published", "Retired"])),
            ("Correct_Answer_Mode__c", "Correct Answer Mode", "Picklist",
             dict(values=["Exact", "AnyOf", "MultiRequired"])),
            ("Explanation__c", "Explanation", "LongTextArea", dict(visible_lines=4)),
            ("Reference_Summary__c", "Reference Summary", "LongTextArea", dict(visible_lines=3)),
            ("Citation_Mode__c", "Citation Mode", "Picklist",
             dict(values=["Official", "Internal", "Generated", "Mixed"])),
            ("External_Id__c", "External Id", "Text", dict(external_id=True, unique=True, length=80)),
            ("Quality_Score__c", "Quality Score", "Number", dict(precision=3, scale=0)),
            ("Times_Asked__c", "Times Asked", "Number", dict(precision=9, scale=0)),
            ("Times_Correct__c", "Times Correct", "Number", dict(precision=9, scale=0)),
            ("Last_Verified_Date__c", "Last Verified Date", "Date", {}),
            ("Hash__c", "Hash", "Text", dict(length=128)),
        ],
    ),
    "Trivia_Answer_Choice__c": dict(
        label="Trivia Answer Choice", plural="Trivia Answer Choices",
        description="Master-detail child of a Trivia Question.",
        fields=[
            ("Trivia_Question__c", "Trivia Question", "MasterDetail",
             dict(reference_to="Trivia_Question__c", relationship_name="Choices", required=True)),
            ("Choice_Label__c", "Choice Label", "Text", dict(length=4)),
            ("Choice_Text__c", "Choice Text", "LongTextArea", dict(visible_lines=2)),
            ("Is_Correct__c", "Is Correct", "Checkbox", dict(default=False)),
            ("Explanation__c", "Explanation", "LongTextArea", dict(visible_lines=2)),
            ("Sort_Order__c", "Sort Order", "Number", dict(precision=3, scale=0)),
        ],
    ),
    "Question_Citation__c": dict(
        label="Question Citation", plural="Question Citations",
        description="External reference backing a question.",
        fields=[
            ("Trivia_Question__c", "Trivia Question", "Lookup",
             dict(reference_to="Trivia_Question__c", relationship_name="Citations", required=True)),
            ("Title__c", "Title", "Text", {}),
            ("URL__c", "URL", "Url", {}),
            ("Source_Type__c", "Source Type", "Picklist",
             dict(values=["Salesforce Help", "Trailhead", "Release Notes", "Internal Guide", "Vendor Docs", "Other"])),
            ("Quote_Or_Reference__c", "Quote Or Reference", "LongTextArea", dict(visible_lines=3)),
            ("Relevance_Note__c", "Relevance Note", "LongTextArea", dict(visible_lines=2)),
            ("Last_Verified_Date__c", "Last Verified Date", "Date", {}),
            ("Verified_By__c", "Verified By", "Lookup",
             dict(reference_to="User", relationship_name="Citations_Verified")),
            ("Broken_Link__c", "Broken Link", "Checkbox", dict(default=False)),
        ],
    ),
    "Game_Session__c": dict(
        label="Game Session", plural="Game Sessions",
        description="An instance of a trivia game in Slack.",
        fields=[
            ("Slack_Channel_Id__c", "Slack Channel Id", "Text", dict(length=40)),
            ("Slack_Team_Id__c", "Slack Team Id", "Text", dict(length=40)),
            ("Started_By_Slack_User_Id__c", "Started By Slack User Id", "Text", dict(length=40)),
            ("Certification_Exam__c", "Certification Exam", "Lookup",
             dict(reference_to="Certification_Exam__c", relationship_name="Game_Sessions", required=True)),
            ("Mode__c", "Mode", "Picklist",
             dict(values=["Solo", "Channel", "Team Battle", "Lightning", "Study", "Exam Sim", "Tournament"])),
            ("Status__c", "Status", "Picklist",
             dict(values=["Setup", "Active", "Paused", "Complete", "Abandoned"])),
            ("Current_Question_Index__c", "Current Question Index", "Number", dict(precision=4, scale=0)),
            ("Total_Questions__c", "Total Questions", "Number", dict(precision=4, scale=0)),
            ("Timer_Seconds__c", "Timer Seconds", "Number", dict(precision=4, scale=0)),
            ("Started_At__c", "Started At", "DateTime", {}),
            ("Completed_At__c", "Completed At", "DateTime", {}),
            ("Anti_Cheat_Seed__c", "Anti Cheat Seed", "Text", dict(length=64)),
            ("Tournament__c", "Tournament", "Lookup",
             dict(reference_to="Tournament__c", relationship_name="Sessions")),
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="Sessions")),
        ],
    ),
    "Game_Round__c": dict(
        label="Game Round", plural="Game Rounds",
        description="One question round inside a session.",
        fields=[
            ("Game_Session__c", "Game Session", "Lookup",
             dict(reference_to="Game_Session__c", relationship_name="Rounds", required=True)),
            ("Round_Number__c", "Round Number", "Number", dict(precision=4, scale=0)),
            ("Trivia_Question__c", "Trivia Question", "Lookup",
             dict(reference_to="Trivia_Question__c", relationship_name="Rounds", required=True)),
            ("Slack_Message_Ts__c", "Slack Message Ts", "Text", dict(length=40, external_id=True)),
            ("Status__c", "Status", "Picklist",
             dict(values=["Posted", "Answered", "Expired", "Explained"])),
            ("Correct_Answer_Revealed__c", "Correct Answer Revealed", "Checkbox", dict(default=False)),
            ("Started_At__c", "Started At", "DateTime", {}),
            ("Ended_At__c", "Ended At", "DateTime", {}),
        ],
    ),
    "Player__c": dict(
        label="Player", plural="Players",
        description="A Slack user playing trivia.",
        fields=[
            ("Slack_User_Id__c", "Slack User Id", "Text", dict(length=40, external_id=True)),
            ("Slack_Team_Id__c", "Slack Team Id", "Text", dict(length=40)),
            ("Salesforce_User__c", "Salesforce User", "Lookup",
             dict(reference_to="User", relationship_name="Trivia_Player")),
            ("Display_Name__c", "Display Name", "Text", dict(length=120)),
            ("Mapped_Contact__c", "Mapped Contact", "Lookup",
             dict(reference_to="Contact", relationship_name="Trivia_Players")),
            ("Total_Points__c", "Total Points", "Number", dict(precision=12, scale=0)),
            ("Total_Games__c", "Total Games", "Number", dict(precision=9, scale=0)),
            ("Accuracy__c", "Accuracy", "Percent", {}),
            ("Current_Streak_Days__c", "Current Streak Days", "Number", dict(precision=5, scale=0)),
            ("Longest_Streak_Days__c", "Longest Streak Days", "Number", dict(precision=5, scale=0)),
            ("Last_Played_At__c", "Last Played At", "DateTime", {}),
            ("Notifications_Opt_In__c", "Notifications Opt In", "Checkbox", dict(default=True)),
            ("Timezone__c", "Timezone", "Text", dict(length=64)),
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="Players")),
        ],
    ),
    "Player_Answer__c": dict(
        label="Player Answer", plural="Player Answers",
        description="One player's answer in a round.",
        fields=[
            ("Game_Session__c", "Game Session", "Lookup",
             dict(reference_to="Game_Session__c", relationship_name="Answers")),
            ("Game_Round__c", "Game Round", "Lookup",
             dict(reference_to="Game_Round__c", relationship_name="Answers", required=True)),
            ("Trivia_Question__c", "Trivia Question", "Lookup",
             dict(reference_to="Trivia_Question__c", relationship_name="Player_Answers")),
            ("Player__c", "Player", "Lookup",
             dict(reference_to="Player__c", relationship_name="Answers", required=True)),
            ("Selected_Choice_Labels__c", "Selected Choice Labels", "Text", dict(length=40)),
            ("Is_Correct__c", "Is Correct", "Checkbox", dict(default=False)),
            ("Points_Awarded__c", "Points Awarded", "Number", dict(precision=8, scale=0)),
            ("Answered_At__c", "Answered At", "DateTime", {}),
            ("Response_Time_Ms__c", "Response Time Ms", "Number", dict(precision=9, scale=0)),
            ("Explanation_Shown__c", "Explanation Shown", "Checkbox", dict(default=False)),
            ("Hint_Used__c", "Hint Used", "Checkbox", dict(default=False)),
            ("Unique_Key__c", "Unique Key", "Text",
             dict(length=80, external_id=True, unique=True)),
        ],
    ),
    "Leaderboard_Snapshot__c": dict(
        label="Leaderboard Snapshot", plural="Leaderboard Snapshots",
        description="Point-in-time leaderboard for a session.",
        fields=[
            ("Game_Session__c", "Game Session", "Lookup",
             dict(reference_to="Game_Session__c", relationship_name="Leaderboard_Snapshots", required=True)),
            ("Snapshot_JSON__c", "Snapshot JSON", "LongTextArea", dict(visible_lines=10)),
            ("Round_Number__c", "Round Number", "Number", dict(precision=4, scale=0)),
            ("Posted_To_Slack__c", "Posted To Slack", "Checkbox", dict(default=False)),
            ("Slack_Message_Ts__c", "Slack Message Ts", "Text", dict(length=40)),
        ],
    ),
    "Tournament__c": dict(
        label="Tournament", plural="Tournaments",
        description="Scheduled multi-session tournament.",
        fields=[
            ("Slack_Team_Id__c", "Slack Team Id", "Text", dict(length=40)),
            ("Certification_Exam__c", "Certification Exam", "Lookup",
             dict(reference_to="Certification_Exam__c", relationship_name="Tournaments", required=True)),
            ("Start_At__c", "Start At", "DateTime", {}),
            ("End_At__c", "End At", "DateTime", {}),
            ("Bracket_Type__c", "Bracket Type", "Picklist",
             dict(values=["RoundRobin", "Elimination", "OpenLadder"])),
            ("Prize_Description__c", "Prize Description", "LongTextArea", dict(visible_lines=3)),
            ("Status__c", "Status", "Picklist",
             dict(values=["Scheduled", "Active", "Complete", "Cancelled"])),
            ("Sponsor_Logo_URL__c", "Sponsor Logo URL", "Url", {}),
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="Tournaments")),
        ],
    ),
    "Achievement__c": dict(
        label="Achievement", plural="Achievements",
        description="Awardable achievement definition.",
        fields=[
            ("Code__c", "Code", "Text", dict(external_id=True, unique=True, length=40)),
            ("Description__c", "Description", "LongTextArea", dict(visible_lines=2)),
            ("Icon_Emoji__c", "Icon Emoji", "Text", dict(length=10)),
            ("Points__c", "Points", "Number", dict(precision=6, scale=0)),
            ("Premium_Only__c", "Premium Only", "Checkbox", dict(default=False)),
        ],
    ),
    "Player_Achievement__c": dict(
        label="Player Achievement", plural="Player Achievements",
        description="Awarded achievement record.",
        fields=[
            ("Player__c", "Player", "Lookup",
             dict(reference_to="Player__c", relationship_name="Achievements", required=True)),
            ("Achievement__c", "Achievement", "Lookup",
             dict(reference_to="Achievement__c", relationship_name="Awards", required=True)),
            ("Awarded_At__c", "Awarded At", "DateTime", {}),
            ("Game_Session__c", "Game Session", "Lookup",
             dict(reference_to="Game_Session__c", relationship_name="Achievements_Awarded")),
            ("Unique_Key__c", "Unique Key", "Text",
             dict(length=80, external_id=True, unique=True)),
        ],
    ),
    "Study_Plan__c": dict(
        label="Study Plan", plural="Study Plans",
        description="Per-player study plan with nudges.",
        fields=[
            ("Player__c", "Player", "Lookup",
             dict(reference_to="Player__c", relationship_name="Study_Plans", required=True)),
            ("Certification_Exam__c", "Certification Exam", "Lookup",
             dict(reference_to="Certification_Exam__c", relationship_name="Study_Plans", required=True)),
            ("Target_Exam_Date__c", "Target Exam Date", "Date", {}),
            ("Daily_Questions__c", "Daily Questions", "Number", dict(precision=3, scale=0)),
            ("Weak_Domains_JSON__c", "Weak Domains JSON", "LongTextArea", dict(visible_lines=4)),
            ("Next_Nudge_At__c", "Next Nudge At", "DateTime", {}),
            ("Active__c", "Active", "Checkbox", dict(default=True)),
        ],
    ),
    "Tenant__c": dict(
        label="Tenant", plural="Tenants",
        description="A Slack workspace using the app.",
        fields=[
            ("Slack_Team_Id__c", "Slack Team Id", "Text",
             dict(length=40, external_id=True, unique=True)),
            ("Workspace_Name__c", "Workspace Name", "Text", dict(length=120)),
            ("Installed_By_User_Id__c", "Installed By User Id", "Text", dict(length=40)),
            ("Installed_At__c", "Installed At", "DateTime", {}),
            ("Plan__c", "Plan", "Picklist",
             dict(values=["Free", "Pro", "Enterprise"])),
            ("Seats_Purchased__c", "Seats Purchased", "Number", dict(precision=6, scale=0)),
            ("Trial_Ends_At__c", "Trial Ends At", "DateTime", {}),
            ("Stripe_Customer_Id__c", "Stripe Customer Id", "Text", dict(length=80)),
            ("Stripe_Subscription_Id__c", "Stripe Subscription Id", "Text", dict(length=80)),
            ("Status__c", "Status", "Picklist",
             dict(values=["Trial", "Active", "PastDue", "Cancelled", "Suspended"])),
            ("Branding_Logo_URL__c", "Branding Logo URL", "Url", {}),
            ("Branding_Primary_Color__c", "Branding Primary Color", "Text", dict(length=10)),
            ("Data_Region__c", "Data Region", "Text", dict(length=40)),
            ("Admin_Slack_User_Ids__c", "Admin Slack User Ids", "LongTextArea", dict(visible_lines=3)),
        ],
    ),
    "License_Event__c": dict(
        label="License Event", plural="License Events",
        description="Stripe / LMA event log (idempotent).",
        fields=[
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="License_Events")),
            ("Event_Type__c", "Event Type", "Picklist",
             dict(values=["TrialStarted", "Upgraded", "Downgraded", "Renewed", "Cancelled", "PaymentFailed", "Other"])),
            ("Stripe_Event_Id__c", "Stripe Event Id", "Text",
             dict(length=120, external_id=True, unique=True)),
            ("Payload_JSON__c", "Payload JSON", "LongTextArea", dict(visible_lines=10)),
            ("Occurred_At__c", "Occurred At", "DateTime", {}),
        ],
    ),
    "Usage_Metric__c": dict(
        label="Usage Metric", plural="Usage Metrics",
        description="Per-tenant monthly metering.",
        fields=[
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="Usage_Metrics", required=True)),
            ("Period__c", "Period", "Text", dict(length=7)),
            ("Games_Started__c", "Games Started", "Number", dict(precision=9, scale=0)),
            ("Questions_Served__c", "Questions Served", "Number", dict(precision=12, scale=0)),
            ("LLM_Tokens_In__c", "LLM Tokens In", "Number", dict(precision=12, scale=0)),
            ("LLM_Tokens_Out__c", "LLM Tokens Out", "Number", dict(precision=12, scale=0)),
            ("LLM_Cost_USD__c", "LLM Cost USD", "Currency", {}),
            ("Active_Players__c", "Active Players", "Number", dict(precision=9, scale=0)),
            ("Unique_Key__c", "Unique Key", "Text",
             dict(length=80, external_id=True, unique=True)),
        ],
    ),
    "Question_Generation_Job__c": dict(
        label="Question Generation Job", plural="Question Generation Jobs",
        description="Async LLM-driven question generation job.",
        fields=[
            ("Certification_Exam__c", "Certification Exam", "Lookup",
             dict(reference_to="Certification_Exam__c", relationship_name="Generation_Jobs", required=True)),
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="Generation_Jobs")),
            ("Requested_By__c", "Requested By", "Lookup",
             dict(reference_to="User", relationship_name="Generation_Jobs_Requested")),
            ("Prompt_Text__c", "Prompt Text", "LongTextArea", dict(visible_lines=10)),
            ("Provider__c", "Provider", "Picklist",
             dict(values=["OpenAI", "Gemini", "Claude", "Manual", "Local"])),
            ("Model__c", "Model", "Text", dict(length=80)),
            ("Status__c", "Status", "Picklist",
             dict(values=["Queued", "Running", "Completed", "Failed", "Needs Review"])),
            ("Requested_Question_Count__c", "Requested Question Count", "Number", dict(precision=4, scale=0)),
            ("Generated_Question_Count__c", "Generated Question Count", "Number", dict(precision=4, scale=0)),
            ("Output_JSON__c", "Output JSON", "LongTextArea", dict(length=131072, visible_lines=20)),
            ("Token_Cost_USD__c", "Token Cost USD", "Currency", {}),
            ("Error_Message__c", "Error Message", "LongTextArea", dict(visible_lines=4)),
        ],
    ),
    "Slack_Event_Log__c": dict(
        label="Slack Event Log", plural="Slack Event Logs",
        description="Idempotency log for incoming Slack events.",
        fields=[
            ("Slack_Event_Id__c", "Slack Event Id", "Text",
             dict(length=120, external_id=True, unique=True)),
            ("Slack_Team_Id__c", "Slack Team Id", "Text", dict(length=40)),
            ("Event_Type__c", "Event Type", "Text", dict(length=80)),
            ("Payload_Hash__c", "Payload Hash", "Text", dict(length=128)),
            ("Received_At__c", "Received At", "DateTime", {}),
            ("Processed__c", "Processed", "Checkbox", dict(default=False)),
            ("Processing_Error__c", "Processing Error", "LongTextArea", dict(visible_lines=3)),
        ],
    ),
    "Audit_Log__c": dict(
        label="Audit Log", plural="Audit Logs",
        description="Append-only audit of admin / reviewer actions.",
        fields=[
            ("Actor_Slack_User_Id__c", "Actor Slack User Id", "Text", dict(length=40)),
            ("Actor_Salesforce_User__c", "Actor Salesforce User", "Lookup",
             dict(reference_to="User", relationship_name="Cert_Audit_Logs")),
            ("Action__c", "Action", "Text", dict(length=80)),
            ("Target_Type__c", "Target Type", "Text", dict(length=80)),
            ("Target_Id__c", "Target Id", "Text", dict(length=40)),
            ("Before_JSON__c", "Before JSON", "LongTextArea", dict(visible_lines=6)),
            ("After_JSON__c", "After JSON", "LongTextArea", dict(visible_lines=6)),
            ("Occurred_At__c", "Occurred At", "DateTime", {}),
        ],
    ),
    "App_Log__c": dict(
        label="App Log", plural="App Logs",
        description="Structured application log for ops/debug.",
        fields=[
            ("Level__c", "Level", "Picklist",
             dict(values=["DEBUG", "INFO", "WARN", "ERROR"])),
            ("Class_Name__c", "Class Name", "Text", dict(length=120)),
            ("Method_Name__c", "Method Name", "Text", dict(length=80)),
            ("Correlation_Id__c", "Correlation Id", "Text", dict(length=80)),
            ("Tenant__c", "Tenant", "Lookup",
             dict(reference_to="Tenant__c", relationship_name="Logs")),
            ("Message__c", "Message", "LongTextArea", dict(visible_lines=4)),
            ("Stack__c", "Stack", "LongTextArea", dict(visible_lines=8)),
            ("Occurred_At__c", "Occurred At", "DateTime", {}),
        ],
    ),
}


def write_object(name: str, spec: dict):
    obj_dir = OBJECTS_DIR / name
    fields_dir = obj_dir / "fields"
    fields_dir.mkdir(parents=True, exist_ok=True)

    # AutoNumber name for log/event objects, Text name for the rest
    autonumber = name in {"Slack_Event_Log__c", "Audit_Log__c", "App_Log__c",
                          "Player_Answer__c", "Game_Round__c", "License_Event__c",
                          "Usage_Metric__c", "Leaderboard_Snapshot__c",
                          "Player_Achievement__c", "Question_Generation_Job__c"}
    nf = "AutoNumber" if autonumber else "Text"

    (obj_dir / f"{name}.object-meta.xml").write_text(
        obj_xml(spec["label"], spec["plural"], spec.get("description", ""), name_type=nf),
        encoding="utf-8",
    )
    for f in spec["fields"]:
        fname, fxml = field(f[0], f[1], f[2], **f[3])
        (fields_dir / fname).write_text(fxml, encoding="utf-8")


def main():
    for name, spec in OBJECTS.items():
        write_object(name, spec)
        print(f"wrote {name} ({len(spec['fields'])} fields)")


if __name__ == "__main__":
    main()
