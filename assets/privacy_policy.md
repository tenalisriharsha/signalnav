# SignalNav Privacy Policy

**Last Updated:** [DATE]  
**Effective Date:** [DATE]

## 1. Introduction

SignalNav ("we," "us," "our") respects your privacy. This Privacy Policy explains how we collect, use, store, and protect your information when you use our mobile application.

## 2. Information We Collect

### 2.1 Location Data
- **What:** GPS coordinates, speed, heading, and timestamp
- **Why:** To provide navigation, detect intersection stops, and generate signal predictions
- **How:** Via your device's location services with your explicit permission
- **Retention:** Raw GPS traces are stored for a maximum of **24 hours**, then permanently deleted

### 2.2 Signal Reports
When you report a signal state, we collect:
- Intersection ID and traffic phase
- Observed signal color (red, yellow, green)
- Timestamp (UTC)
- Hashed device identifier (NOT your Firebase UID or any personal identifier)
- Your speed at the time of report

### 2.3 Account Information
If you sign in with Google:
- Email address (stored only for authentication)
- Anonymous UID (used internally for trust scoring)

### 2.4 Device Information
- Device type and OS version (for compatibility)
- App version and crash logs (if crash reporting is enabled)

## 3. Information We Do NOT Collect

We explicitly do **NOT** collect:
- Your name, phone number, or mailing address
- Precise home or work locations
- Driving history or travel patterns
- Contacts, photos, or other personal files
- Data for advertising or marketing purposes

## 4. How We Use Your Information

| Data | Purpose |
|------|---------|
| Location | Navigation, intersection detection, signal prediction |
| Signal Reports | Aggregated community predictions |
| Device Hash | Trust scoring and outlier detection |
| Crash Logs | App stability improvements |

## 5. Data Sharing and Sales

**We do not sell, rent, or trade your personal information to any third party.**

Aggregated, anonymized prediction data may be made publicly available through the App's prediction feature. This data cannot be traced back to any individual user.

## 6. Data Security

We implement industry-standard measures:
- Firebase Firestore security rules restrict data access
- All signal reports are anonymized before aggregation
- Raw GPS traces are automatically purged after 24 hours
- Communications with our servers use TLS encryption

## 7. Your Rights

Depending on your jurisdiction, you may have the right to:

### 7.1 Access and Export
Request a copy of your personal data via the in-app Settings menu.

### 7.2 Deletion
Delete your account and all associated data via Settings. This will:
- Remove your Firebase Auth account
- Anonymize all your historical signal reports
- Permanently delete your user profile

### 7.3 Opt-Out
You may disable crowdsourcing in Settings while continuing to use navigation features.

### 7.4 Correction
Update incorrect information by contacting us.

## 8. Children's Privacy

SignalNav is not intended for children under 13. We do not knowingly collect data from children under 13. If you believe we have inadvertently collected such data, contact us for deletion.

## 9. International Users

If you are located outside the United States, your data is processed in the United States where our Firebase servers are hosted. By using the App, you consent to this transfer.

## 10. Changes to This Policy

We may update this Privacy Policy. Material changes will be communicated via in-app notification. Continued use after changes constitutes acceptance.

## 11. Contact Us

Privacy inquiries: [privacy@signalnav.example.com]  
Data Protection Officer: [dpo@signalnav.example.com]

---

**IMPORTANT:** This Privacy Policy is a placeholder template. Before releasing SignalNav to the public, you MUST have this document reviewed and approved by a licensed attorney in your jurisdiction, particularly to ensure compliance with GDPR (EU), CCPA (California), and any other applicable privacy regulations.
