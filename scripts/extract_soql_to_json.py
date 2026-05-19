#!/usr/bin/env python3
"""
Extract SOQL queries from markdown file and save as JSON array (one per line).
"""

import re
import json

def extract_soql_queries(markdown_file):
    """Extract all SOQL queries from markdown file."""
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match SQL code blocks
    pattern = r'```sql\n(.*?)\n```'
    matches = re.findall(pattern, content, re.DOTALL)
    
    queries = []
    for match in matches:
        # Remove comment lines and clean up
        lines = match.strip().split('\n')
        query_lines = []
        
        for line in lines:
            stripped = line.strip()
            # Skip comment-only lines
            if stripped.startswith('--'):
                continue
            # Remove inline comments
            if '--' in stripped:
                stripped = stripped.split('--')[0].strip()
            if stripped:
                query_lines.append(stripped)
        
        if query_lines:
            # Join lines and normalize whitespace
            query = ' '.join(query_lines)
            # Normalize multiple spaces to single space
            query = ' '.join(query.split())
            queries.append(query)
    
    return queries

def main():
    markdown_file = 'docs/soql-query-reference.md'
    output_file = 'docs/soql-queries.json'
    
    print(f"Extracting SOQL queries from {markdown_file}...")
    queries = extract_soql_queries(markdown_file)
    
    print(f"Found {len(queries)} queries")
    
    # Write as JSON array with one query per line
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('[\n')
        for i, query in enumerate(queries):
            json_str = json.dumps(query)
            if i < len(queries) - 1:
                f.write(f'  {json_str},\n')
            else:
                f.write(f'  {json_str}\n')
        f.write(']\n')
    
    print(f"Saved {len(queries)} queries to {output_file}")
    
    # Print first few as sample
    print("\nSample queries:")
    for i, query in enumerate(queries[:3]):
        print(f"\nQuery {i+1}:")
        print(query[:100] + "..." if len(query) > 100 else query)

if __name__ == '__main__':
    main()