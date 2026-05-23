# Steps to Import Certification Exams

1. Convert the source CSV to Salesforce format:

   ```sh
   python scripts/convert_cert_csv.py \
     "/Users/clayboss/Downloads/All Tests in Salesforce Certifications - Sheet1.csv" \
     scripts/certification_exams.csv
   ```

2. Import into Salesforce using sfdx:

   ```sh
   sf data bulk upsert -s Certification_Exam__c -f scripts/certification_exams.csv -i Certification_Code__c
   ```

3. When importing or generating Trivia_Question__c, always set the Certification_Exam__c lookup by querying Certification_Exam__c where Certification_Code__c matches the exam code.

4. All future question imports/scripts must enforce this parent linkage.

See docs/certification_exam_import.md for details.
