// Seed two Study Guide themes so the picker has options. Re-runnable: upserts by Theme_Key__c.
List<Study_Guide_Theme__c> themes = new List<Study_Guide_Theme__c>{
    new Study_Guide_Theme__c(
        Name = 'Editorial (default)',
        Theme_Key__c = 'editorial',
        Description__c = 'The original magazine-style readiness report.',
        Active__c = true,
        Is_Default__c = true,
        Sort_Order__c = 10,
        Body__c = ''  // empty = falls back to readinessReportTemplate static resource
    ),
    new Study_Guide_Theme__c(
        Name = 'Quick Snapshot',
        Theme_Key__c = 'snapshot',
        Description__c = 'Single-page summary - just the numbers that matter.',
        Active__c = true,
        Is_Default__c = false,
        Sort_Order__c = 20,
        Body__c = '<!doctype html><html><head><meta charset="utf-8"><title>{{cert_name}} - Snapshot</title>'
            + '<style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#0b0d12;color:#e6e8ec;margin:0;padding:40px;}'
            + '.card{max-width:760px;margin:0 auto;background:#151821;border:1px solid #2a2f3a;border-radius:14px;padding:36px;}'
            + 'h1{margin:0 0 4px;font-size:28px;letter-spacing:-0.5px;}h2{margin:24px 0 8px;color:#8ea0bd;font-weight:500;font-size:13px;text-transform:uppercase;letter-spacing:1px;}'
            + '.row{display:flex;gap:14px;margin-top:14px;}.kpi{flex:1;background:#1e2230;border:1px solid #2a2f3a;border-radius:10px;padding:18px;}'
            + '.k{font-size:11px;text-transform:uppercase;color:#8ea0bd;letter-spacing:1px;margin-bottom:6px;}.v{font-size:30px;font-weight:600;}'
            + '.muted{color:#8ea0bd;font-size:14px;line-height:1.55;}.verdict{margin-top:24px;padding:18px;background:#0f1320;border-radius:10px;border-left:3px solid #4cc38a;}</style></head>'
            + '<body><div class="card"><h1>{{cert_name}}</h1><div class="muted">Snapshot for {{user_name}} - {{report_date}}</div>'
            + '<h2>Headline</h2><div class="muted">{{headline_verdict}}</div>'
            + '<h2>Numbers</h2><div class="row">'
            + '<div class="kpi"><div class="k">Accuracy</div><div class="v">{{overall_accuracy}}%</div></div>'
            + '<div class="kpi"><div class="k">Questions</div><div class="v">{{total_questions}}</div></div>'
            + '<div class="kpi"><div class="k">Streak</div><div class="v">{{streak_days}}d</div></div>'
            + '<div class="kpi"><div class="k">Readiness</div><div class="v">{{readiness_score}}</div></div>'
            + '</div><div class="verdict">{{verdict_paragraph}}</div></div></body></html>'
    ),
    new Study_Guide_Theme__c(
        Name = 'Printable Report',
        Theme_Key__c = 'printable',
        Description__c = 'Clean black-and-white layout for printing.',
        Active__c = true,
        Is_Default__c = false,
        Sort_Order__c = 30,
        Body__c = '<!doctype html><html><head><meta charset="utf-8"><title>{{cert_name}} - Study Guide</title>'
            + '<style>body{font-family:Georgia,"Times New Roman",serif;color:#111;background:#fff;margin:0;padding:48px 56px;}'
            + 'h1{font-size:32px;margin:0 0 4px;}h2{font-size:18px;border-bottom:2px solid #111;padding-bottom:4px;margin-top:32px;}'
            + 'table{width:100%;border-collapse:collapse;margin-top:12px;}th,td{padding:8px 10px;border-bottom:1px solid #ddd;text-align:left;}th{background:#f4f4f4;}'
            + '.subtitle{color:#555;margin-bottom:24px;}p{line-height:1.6;}.box{border:1px solid #111;padding:16px;margin-top:24px;}'
            + '@media print{body{padding:24px;}}</style></head>'
            + '<body><h1>{{cert_name}} - Study Guide</h1><div class="subtitle">Prepared for {{user_name}} on {{report_date}} (report #{{report_number}})</div>'
            + '<h2>Headline</h2><p>{{headline_verdict}}</p>'
            + '<h2>Summary</h2><p>{{summary_paragraph_1}}</p><p>{{summary_paragraph_2}}</p>'
            + '<h2>Readiness</h2><table>'
            + '<tr><th>Accuracy</th><td>{{overall_accuracy}}%</td></tr>'
            + '<tr><th>Questions Answered</th><td>{{total_questions}}</td></tr>'
            + '<tr><th>Sessions</th><td>{{total_sessions}}</td></tr>'
            + '<tr><th>Current Streak</th><td>{{streak_days}} days</td></tr>'
            + '<tr><th>Readiness Score</th><td>{{readiness_score}} / 100 ({{readiness_label}})</td></tr>'
            + '<tr><th>Exam Date</th><td>{{exam_date}} ({{days_until_exam}} days)</td></tr>'
            + '</table>'
            + '<h2>Domain breakdown</h2><div>{{domain_rows_html}}</div>'
            + '<h2>Verdict</h2><div class="box">{{verdict_paragraph}}</div>'
            + '<h2>Recommendations</h2><div>{{recommendations_html}}</div>'
            + '</body></html>'
    )
};
upsert themes Theme_Key__c;
System.debug('Upserted ' + themes.size() + ' Study Guide themes.');
for (Study_Guide_Theme__c t : themes) System.debug(' - ' + t.Theme_Key__c + ' (id=' + t.Id + ', default=' + t.Is_Default__c + ')');
