import csv
import sys

# Usage: python scripts/convert_cert_csv.py /path/to/All\ Tests\ in\ Salesforce\ Certifications\ -\ Sheet1.csv scripts/certification_exams.csv

input_path = sys.argv[1]
output_path = sys.argv[2]

with open(input_path, newline='', encoding='utf-8') as infile, open(output_path, 'w', newline='', encoding='utf-8') as outfile:
    reader = csv.DictReader(infile)
    fieldnames = [
        'Name', 'Certification_Code__c', 'Track__c', 'Level__c', 'Cost__c', 'Notes__c'
    ]
    writer = csv.DictWriter(outfile, fieldnames=fieldnames)
    writer.writeheader()
    for row in reader:
        writer.writerow({
            'Name': row['Certification Name'],
            'Certification_Code__c': row['Exam Code'],
            'Track__c': row['Track'],
            'Level__c': row['Level'],
            'Cost__c': row['Cost USD'],
            'Notes__c': row['Notes']
        })
print(f"Wrote {output_path}")
