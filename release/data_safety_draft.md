# Data Safety Draft

Last updated: `2026-03-23`

This draft is intended as a working reference for Play Console data safety answers. Review against the final production build and hosted privacy policy before submission.

## Data Types

### App activity

- Potentially processed by ad SDK flows:
  - app interactions related to ad requests and completion state
- Purpose:
  - advertising
  - fraud prevention / security

### Device or other identifiers

- Potentially processed by ad SDK flows:
  - advertising ID or similar device/app identifiers
- Purpose:
  - advertising
  - consent and compliance

### Personal info

- Not intentionally collected by the game in the current repository state
- Support email/contact information is external to the game client

### Financial info

- Not collected

### Location

- Not directly collected by game logic
- Any regional handling would come from platform or ad SDK behavior

## Data Handling Notes

- Gameplay save data is stored locally on-device
- No account login is required
- No production analytics SDK is wired in this repository state
- Advertising behavior exists on Android and depends on consent and SDK availability

## Draft Submission Position

- Data collected: only to the extent required by ad SDK and consent flow
- Data shared: may be shared with ad providers as part of ad serving/compliance
- Required for app functionality: local save data yes, ad SDK data no
- User can request deletion: local data can be cleared by uninstalling or clearing app data

