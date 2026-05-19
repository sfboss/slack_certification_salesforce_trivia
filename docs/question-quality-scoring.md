# Question Quality Scoring Guide

This guide provides a systematic framework for evaluating the quality of trivia questions, whether AI-generated or human-authored. Use this scoring rubric during the review process in the `questionReviewConsole` LWC to ensure consistent, high-quality content.

---

## Overview

Every question should be evaluated across **six dimensions**. Each dimension is scored 0-5, with a maximum total score of 30 points. Questions scoring below 18 should be rejected or require major revision.

| Score Range | Quality Level | Action |
|-------------|---------------|--------|
| 27-30 | Excellent | Publish immediately |
| 23-26 | Good | Minor polish, then publish |
| 18-22 | Fair | Revise and re-review |
| 0-17 | Poor | Reject or major rewrite |

---

## Scoring Dimensions

### 1. Accuracy (0-5 points)

**Does the question present factually correct information aligned with official Salesforce documentation?**

- **5 pts**: Completely accurate; aligns perfectly with current Salesforce docs/features
- **4 pts**: Accurate with minor version-specific nuances (e.g., "as of Spring '24")
- **3 pts**: Mostly accurate but missing important caveats or edge cases
- **2 pts**: Contains one significant factual error
- **1 pt**: Multiple factual errors or outdated information
- **0 pts**: Fundamentally incorrect or contradicts official docs

**Red Flags:**
- References deprecated features without noting deprecation
- Uses outdated API versions (< 55.0 for modern questions)
- Contradicts Trailhead modules or official guides
- Contains "trick" wording that misleads on actual functionality

**Validation Checklist:**
- [ ] Cross-referenced with official Salesforce docs (link in `Question_Citation__c`)
- [ ] Verified correct answer aligns with current Salesforce behavior
- [ ] No deprecated features unless explicitly teaching legacy patterns
- [ ] Version-specific details noted if applicable

---

### 2. Clarity (0-5 points)

**Is the question unambiguous and easily understood by the target audience?**

- **5 pts**: Crystal clear; no possibility of misinterpretation
- **4 pts**: Clear with minor wording that could be tightened
- **3 pts**: Understandable but requires re-reading
- **2 pts**: Ambiguous phrasing; multiple interpretations possible
- **1 pt**: Confusing structure or unclear what's being asked
- **0 pts**: Incomprehensible or grammatically broken

**Red Flags:**
- Double negatives ("Which is NOT incorrect...")
- Unclear antecedents ("What does IT do?")
- Mixing multiple concepts without clear separation
- Run-on sentences exceeding 40 words
- Jargon without context (assuming knowledge not in prerequisites)

**Best Practices:**
- Use active voice
- One concept per question
- Define acronyms on first use within question text
- Keep question stem under 30 words when possible
- Choices should be parallel in structure

---

### 3. Relevance (0-5 points)

**Does the question test meaningful knowledge for the target certification/exam domain?**

- **5 pts**: Core competency; appears on official exam objectives
- **4 pts**: Highly relevant supporting knowledge
- **3 pts**: Tangentially related but useful
- **2 pts**: Marginally relevant; edge case scenario
- **1 pt**: Trivia that doesn't aid certification prep
- **0 pts**: Completely off-topic for the exam

**Red Flags:**
- Questions about rarely-used features with no exam coverage
- Testing minutiae (e.g., "What year was Salesforce founded?")
- Requiring knowledge beyond the exam level (e.g., Einstein AI on Admin exam)
- Personal opinion questions with no objective answer

**Alignment Check:**
- [ ] Maps to specific `Exam_Domain__c` objective
- [ ] Difficulty appropriate for `Certification_Exam__c.Level__c`
- [ ] Practical scenario or commonly-tested concept
- [ ] Helps learners avoid real-world mistakes

---

### 4. Distractors Quality (0-5 points)

**Are the incorrect answer choices plausible, non-overlapping, and educational?**

- **5 pts**: All distractors are plausible and teach common misconceptions
- **4 pts**: Most distractors are strong; one is slightly weak
- **3 pts**: At least two strong distractors; others obvious
- **2 pts**: Only one plausible distractor
- **1 pt**: All distractors are implausible or silly
- **0 pts**: Distractors overlap or make no sense

**Characteristics of Strong Distractors:**
- Represent common beginner mistakes
- Are technically possible but suboptimal
- Test understanding of "why not" this approach
- Are similar length/complexity to correct answer
- Don't include absolutes ("always", "never") unless correct answer does too

**Red Flags:**
- Obviously joke answers ("Hire a consultant")
- Distractors that are technically correct in different contexts
- Two choices that mean the same thing
- One choice significantly longer/more detailed than others (often the correct answer)
- Made-up features that don't exist in Salesforce

**Example (Poor vs. Good):**

❌ **Poor Distractors:**
```
Q: What permission is needed to delete records?
A) Delete
B) Edit
C) Banana
D) Superman powers
```

✅ **Good Distractors:**
```
Q: What permission is needed to delete records?
A) Delete ✓
B) Edit (tests confusion with edit permission)
C) Modify All Data (tests understanding of object vs. org permissions)
D) View All (tests understanding of CRUD separation)
```

---

### 5. Explanation Quality (0-5 points)

**Does the explanation teach the concept and clarify why distractors are incorrect?**

- **5 pts**: Comprehensive; explains correct answer AND why each distractor is wrong
- **4 pts**: Strong explanation of correct answer; brief mention of distractors
- **3 pts**: Adequate explanation of correct answer; no distractor discussion
- **2 pts**: Minimal explanation; doesn't add value beyond repeating answer
- **1 pt**: Vague or incomplete explanation
- **0 pts**: No explanation or explanation contradicts question

**Best Practices:**
- Start with "Why X is correct:"
- Include "Why others are incorrect:" section
- Provide a real-world use case or example
- Link to additional learning resources (Trailhead, docs)
- Use analogies when explaining complex concepts

**Template:**
```
Why [Correct Answer] is correct:
[1-2 sentences explaining the concept and when to use it]

Why other options are incorrect:
• [Option B]: [Brief reason - common misconception addressed]
• [Option C]: [Brief reason - key difference highlighted]
• [Option D]: [Brief reason - when this might seem correct but isn't]

Learn more: [Trailhead module/doc link]
```

**Red Flags:**
- Copy-pasting question text into explanation
- No educational value; just confirming answer
- Incorrect information in explanation
- No citations for complex topics
- Explanation longer than question (> 150 words)

---

### 6. Citation Strength (0-5 points)

**Are sources authoritative, accessible, and recent?**

- **5 pts**: Multiple authoritative sources; all links valid; current (< 1 year old)
- **4 pts**: One authoritative source; link valid; reasonably current
- **3 pts**: Valid source but outdated (> 2 years) or generic
- **2 pts**: Weak source (e.g., random blog); link works
- **1 pt**: No link provided; only source title
- **0 pts**: No citation or link is broken

**Authoritative Sources (Ranked):**
1. **Tier 1 (5 pts)**: Salesforce official docs, Trailhead, Release Notes, Help articles
2. **Tier 2 (4 pts)**: Salesforce Developer Blog, official MVPs, Architect guides
3. **Tier 3 (3 pts)**: Trailblazer Community (verified answers), Salesforce DX guides
4. **Tier 4 (2 pts)**: Reputable third-party Salesforce blogs (e.g., SFBen, Bob Buzzard)
5. **Tier 5 (1 pt)**: Generic tutorials, personal blogs, outdated sources

**Citation Format:**
```
Source: [Title of Document/Page]
URL: [Full HTTPS URL]
Last Verified: [YYYY-MM-DD]
```

**Red Flags:**
- Linking to paywalled content
- Linking to competitor products as "the way"
- No citation for complex/debatable topics
- Linking to non-HTTPS URLs
- Links requiring login to view
- Circular citations (linking to other trivia sites)

**Automated Checks:**
- Run `scripts/verify-citations.py` to validate all URLs
- Flag any citations with `Question_Citation__c.Broken_Link__c = true`
- Scheduled Apex `CertGameCitationCrawler` (not yet implemented) will check nightly

---

## Composite Score Examples

### Example 1: Excellent Question (Score: 28/30)

**Question:**
> A user needs to update Lead records but should not be able to delete them. Which permission should be granted?

**Choices:**
- A) Edit on Leads ✓
- B) Delete on Leads
- C) Modify All Data
- D) View All and Modify All

**Explanation:**
> Why Edit on Leads is correct:
> The Edit permission allows creating and updating records but does not include deletion. This follows the principle of least privilege.
>
> Why other options are incorrect:
> • Delete on Leads: Grants deletion rights, which the requirement explicitly excludes
> • Modify All Data: Org-wide permission that includes deletion across all objects—far too broad
> • View All and Modify All: These permissions grant view/edit access but still require Delete to remove records; however, this is overly permissive
>
> Learn more: https://help.salesforce.com/s/articleView?id=sf.users_profiles_object_perms.htm

**Scoring:**
- Accuracy: 5/5 (Correct per official docs)
- Clarity: 5/5 (No ambiguity)
- Relevance: 5/5 (Core Admin exam topic)
- Distractors: 4/5 (All plausible; D is slightly convoluted)
- Explanation: 5/5 (Clear, educational, addresses all choices)
- Citation: 4/5 (Official Help article, valid link)
- **Total: 28/30** → Publish

---

### Example 2: Fair Question (Score: 20/30)

**Question:**
> What's the thing you click to make a formula field?

**Choices:**
- A) Formula return type
- B) New Custom Field button ✓
- C) Settings
- D) Go to formula wizard

**Explanation:**
> You need to click the New Custom Field button.

**Scoring:**
- Accuracy: 4/5 (Technically correct but vague)
- Clarity: 2/5 (Unprofessional phrasing; "the thing you click")
- Relevance: 4/5 (Relevant but too basic)
- Distractors: 2/5 (A and D are nonsensical)
- Explanation: 1/5 (No educational value; restates question)
- Citation: 0/5 (No citation provided)
- **Total: 13/30** → Reject and rewrite

**Recommended Fix:**
> **Question:** Where in Setup do you initiate creating a new Formula field on the Account object?
> 
> **Choices:**
> - A) Setup > Object Manager > Account > Fields & Relationships > New ✓
> - B) Setup > Formula Fields > New
> - C) Setup > Customization > Formula Wizard
> - D) The account record page > Edit
>
> **Explanation:** Formula fields are created through Object Manager, navigating to the specific object, then Fields & Relationships. Option B is incorrect as there's no global "Formula Fields" node. Option C references a non-existent wizard. Option D only allows editing existing field values, not creating field definitions.

**Revised Score:** ~25/30 → Acceptable after edits

---

## Integration with Review Workflow

### In `questionReviewConsole` LWC

Add a "Quality Score" section:

```html
<lightning-card title="Quality Score">
  <div class="slds-p-around_medium">
    <!-- Score sliders for each dimension -->
    <lightning-input 
      type="number" 
      label="Accuracy (0-5)" 
      max="5" 
      value={accuracyScore}>
    </lightning-input>
    <!-- Repeat for each dimension -->
    
    <div class="slds-text-heading_medium">
      Total Score: {totalScore}/30
    </div>
    <lightning-badge 
      label={scoreLabel} 
      class={scoreBadgeClass}>
    </lightning-badge>
  </div>
</lightning-card>
```

### Apex Integration

Store scores in `Trivia_Question__c`:

```apex
public with sharing class QuestionQualityScorer {
  public class ScoreBreakdown {
    @AuraEnabled public Integer accuracy;
    @AuraEnabled public Integer clarity;
    @AuraEnabled public Integer relevance;
    @AuraEnabled public Integer distractors;
    @AuraEnabled public Integer explanation;
    @AuraEnabled public Integer citation;
    @AuraEnabled public Integer total;
    @AuraEnabled public String qualityLevel; // Excellent/Good/Fair/Poor
  }
  
  @AuraEnabled
  public static void saveQ