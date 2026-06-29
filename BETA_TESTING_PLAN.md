# Roam – Beta Testing Plan

**Version:** 1.0  
**Date:** June 28, 2026  
**App:** Roam – iOS Package Tracking  
**Repo:** https://github.com/pri8771/ios_tracker_app

---

## Overview

Roam is a local-first iOS app that tracks packages from UPS, FedEx, USPS, DHL, and other carriers. It uses device location for delivery estimates, requires no account, and functions offline with cached data.

This 3-phase beta testing plan covers internal alpha, external TestFlight beta, and final polish before App Store submission.

---

## Phase 1: Internal Alpha (Week 1–2)

**Goal:** Validate core functionality, data persistence, and location features with internal team.

### Testers
- Developers and close collaborators (3–5 people)
- - Devices: iPhone 14, iPhone 15 Pro, iPhone SE (3rd gen)
  - - iOS versions: iOS 16, 17, 18
   
    - ### Test Cases
   
    - #### Core Package Tracking
    - - [ ] Add a new tracking number (UPS format: 1Z...)
      - [ ] - [ ] Add a FedEx tracking number (12-digit)
      - [ ] - [ ] Add a USPS tracking number (22-digit)
      - [ ] - [ ] Add a DHL tracking number
      - [ ] - [ ] View package status and shipment history
      - [ ] - [ ] Delete a tracked package
      - [ ] - [ ] Add custom package nickname
      - [ ] - [ ] Add multiple packages simultaneously (10+)
     
      - [ ] #### Offline Functionality
      - [ ] - [ ] Enable airplane mode, verify cached packages still visible
      - [ ] - [ ] Confirm last-known status displayed when offline
      - [ ] - [ ] Re-enable connectivity, verify packages refresh
      - [ ] - [ ] Kill and relaunch app in airplane mode – data persists
     
      - [ ] #### Location Services
      - [ ] - [ ] Prompt appears correctly on first location use
      - [ ] - [ ] Deny location – app functions without crashing
      - [ ] - [ ] Allow location – delivery estimates appear
      - [ ] - [ ] Revoke location in Settings – app handles gracefully
      - [ ] - [ ] Verify no continuous background location drain
     
      - [ ] #### Data Persistence
      - [ ] - [ ] Force-quit app, relaunch – packages still present
      - [ ] - [ ] Restart device – packages still present
      - [ ] - [ ] Add 50+ packages – no performance degradation
     
      - [ ] #### Error States
      - [ ] - [ ] Enter invalid tracking number – appropriate error shown
      - [ ] - [ ] Network timeout – user-friendly message
      - [ ] - [ ] Unknown carrier format – handled gracefully
      - [ ] - [ ] Empty state UI when no packages added
     
      - [ ] #### Notifications (if enabled)
      - [ ] - [ ] Enable notifications – permission prompt appears
      - [ ] - [ ] Delivery estimate notification triggers correctly
      - [ ] - [ ] Notification taps open correct package detail
      - [ ] - [ ] Disable notifications in Settings – no crashes
     
      - [ ] ### Alpha Success Criteria
      - [ ] - Zero crashes on primary flows
      - [ ] - All 4 carriers trackable
      - [ ] - Offline mode works correctly
      - [ ] - Location denial handled gracefully
      - [ ] - Data persistence verified on restart
     
      - [ ] ---
     
      - [ ] ## Phase 2: External Beta via TestFlight (Week 3–5)
     
      - [ ] **Goal:** Validate app with real users, different network conditions, and real tracking numbers.
     
      - [ ] ### Tester Recruitment
      - [ ] - Target: 25–50 external testers
      - [ ] - Recruit from: Reddit (r/shortcuts, r/iphone), ProductHunt, Twitter/X, personal network
      - [ ] - Profile: Frequent online shoppers who track 3+ packages/week
      - [ ] - Device spread: Mix of iPhone models, iOS 16+
     
      - [ ] ### Distribution
      - [ ] - Upload to App Store Connect
      - [ ] - Enable TestFlight external testing
      - [ ] - Share invite link with recruited testers
      - [ ] - Collect feedback via TestFlight built-in survey + optional Google Form
     
      - [ ] ### Focus Areas for External Beta
     
      - [ ] #### Real-World Tracking Numbers
      - [ ] - [ ] Testers add their own real UPS/FedEx/USPS/DHL tracking numbers
      - [ ] - [ ] Verify status updates reflect real carrier data
      - [ ] - [ ] Test with international shipments (DHL cross-border)
      - [ ] - [ ] Test with regional carriers if applicable
     
      - [ ] #### User Experience
      - [ ] - [ ] Onboarding flow is clear without instructions
      - [ ] - [ ] Adding first package takes < 30 seconds
      - [ ] - [ ] Package list is easy to scan and navigate
      - [ ] - [ ] Status updates are easy to understand
     
      - [ ] #### Performance
      - [ ] - [ ] App launches in < 2 seconds on older devices (iPhone XS)
      - [ ] - [ ] Package list scrolls smoothly with 20+ items
      - [ ] - [ ] Tracking refresh completes in < 10 seconds on WiFi
      - [ ] - [ ] Battery impact is minimal (no background drain reports)
     
      - [ ] #### Location Features
      - [ ] - [ ] Delivery estimates feel useful and accurate
      - [ ] - [ ] Location permission prompt language is clear
      - [ ] - [ ] Location-based features don't feel invasive
     
      - [ ] #### Edge Cases
      - [ ] - [ ] Tracking number for delivered package
      - [ ] - [ ] Tracking number that is invalid/expired
      - [ ] - [ ] Package stuck "in transit" for 7+ days
      - [ ] - [ ] Multiple packages from same carrier
     
      - [ ] ### Beta Feedback Collection
      - [ ] - TestFlight built-in ratings and screenshots
      - [ ] - Optional feedback form (Google Form or Typeform)
      - [ ] - Weekly check-in with top 5 power users
      - [ ] - Crash reports via Xcode Organizer / Crashlytics (if enabled)
     
      - [ ] ### External Beta Success Criteria
      - [ ] - Crash-free rate > 99%
      - [ ] - Average session length > 2 minutes
      - [ ] - At least 15 testers provide written feedback
      - [ ] - No P0 (critical) bugs remaining
      - [ ] - App Store review readiness confirmed
     
      - [ ] ---
     
      - [ ] ## Phase 3: Polish & Pre-Launch (Week 6)
     
      - [ ] **Goal:** Final refinements, accessibility audit, App Store metadata review.
     
      - [ ] ### Accessibility Audit
      - [ ] - [ ] VoiceOver: All interactive elements have meaningful labels
      - [ ] - [ ] Dynamic Type: Text scales correctly at all sizes
      - [ ] - [ ] Reduce Motion: Animations respect system setting
      - [ ] - [ ] High Contrast: UI remains legible
      - [ ] - [ ] Color blindness: No color-only information conveyed
     
      - [ ] ### App Store Readiness
      - [ ] - [ ] App icon: 1024x1024 PNG, no alpha
      - [ ] - [ ] Screenshots: iPhone 6.7" and 5.5" sizes
      - [ ] - [ ] App Store description written and reviewed
      - [ ] - [ ] Keywords optimized for package tracking searches
      - [ ] - [ ] Privacy Nutrition Label (PRIVACY_POLICY.md) matches App Store data declaration
      - [ ] - [ ] Age rating: 4+ (no objectionable content)
      - [ ] - [ ] Support URL: GitHub repo or dedicated support page
      - [ ] - [ ] TERMS_OF_SERVICE.md reviewed and linked
     
      - [ ] ### Final QA Checklist
      - [ ] - [ ] Clean install on fresh device – no setup required
      - [ ] - [ ] App behaves correctly after iOS update
      - [ ] - [ ] No console errors or warnings in release build
      - [ ] - [ ] Memory usage stable after 30-minute session
      - [ ] - [ ] App does not request unnecessary permissions
      - [ ] - [ ] All links and URLs in app are valid
     
      - [ ] ### Known Issues to Document Before Launch
      - [ ] - Carrier API rate limits may delay status updates
      - [ ] - Some regional carriers may not be supported in v1.0
      - [ ] - International tracking numbers may have variable format support
     
      - [ ] ---
     
      - [ ] ## Bug Severity Levels
     
      - [ ] | Level | Description | Resolution Time |
      - [ ] |-------|-------------|-----------------|
      - [ ] | P0 – Critical | App crash, data loss, security issue | Block launch, fix immediately |
      - [ ] | P1 – High | Core feature broken, major UX failure | Fix before App Store submission |
      - [ ] | P2 – Medium | Minor feature broken, edge case issue | Fix in v1.1 if not blocking |
      - [ ] | P3 – Low | Cosmetic, minor copy issue | Backlog |
     
      - [ ] ---
     
      - [ ] ## Success Metrics for Launch Readiness
     
      - [ ] | Metric | Target |
      - [ ] |--------|--------|
      - [ ] | Crash-free rate | > 99.5% |
      - [ ] | P0 bugs | 0 |
      - [ ] | P1 bugs | 0 |
      - [ ] | App Store rating (beta) | > 4.0 |
      - [ ] | External beta testers | ≥ 20 active |
      - [ ] | Accessibility audit | Pass |
      - [ ] | CI build status | Green |
     
      - [ ] ---
     
      - [ ] ## Timeline Summary
     
      - [ ] | Phase | Duration | Goal |
      - [ ] |-------|----------|------|
      - [ ] | Phase 1: Internal Alpha | Week 1–2 | Core validation |
      - [ ] | Phase 2: External Beta | Week 3–5 | Real-world validation |
      - [ ] | Phase 3: Polish | Week 6 | App Store readiness |
      - [ ] | **App Store Submission** | Week 7 | Launch |
     
      - [ ] ---
     
      - [ ] ## Contacts
     
      - [ ] - **Developer:** pri8771
      - [ ] - **GitHub Repo:** https://github.com/pri8771/ios_tracker_app
      - [ ] - **TestFlight Feedback:** Via App Store Connect
      - [ ] 
