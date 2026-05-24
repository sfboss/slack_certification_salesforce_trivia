# Certification Exam Import & Linking Guide

This project uses Certification_Exam**c as the parent object for all certification exams. Each exam is uniquely identified by Certification_Code**c (External ID, unique).

## Data Model

- **Certification_Exam\_\_c**
    - Name (Text)
    - Certification_Code\_\_c (Text, External ID, unique)
    - Track, Level, Cost, Notes, etc. (add fields as needed)
- **Trivia_Question\_\_c**
    - Certification_Exam\_\_c (Lookup, required)

## Importing Exams from CSV

1. Convert your source CSV to a new CSV with these columns:
    - Name, Certification_Code**c, Track**c, Level**c, Cost**c, Notes\_\_c
2. Use sfdx to import:
    ```sh
    sf data bulk upsert -s Certification_Exam__c -f scripts/certification_exams.csv -i Certification_Code__c
    ```

## Linking Questions to Exams

- When importing or generating Trivia_Question**c, always set Certification_Exam**c by looking up the parent via Certification_Code\_\_c.
- In Apex/scripts, query Certification_Exam**c by Certification_Code**c to get the Id for linking.

## Example: Linking in Python

```python
# Pseudocode
exam = sf.Certification_Exam__c.get_by_custom_id('Certification_Code__c', 'Plat-101')
question['Certification_Exam__c'] = exam['Id']
```

## Maintenance

- Keep Certification_Exam\_\_c up to date with new/retired exams.
- All questions must reference a valid Certification_Exam\_\_c.

---

See also: AGENTS.md phase 1-2 for data model and import pipeline details.
