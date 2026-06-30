# Roam — Project Documentation

GitHub is the source of truth for this project documentation. Notion indexes this file in the Priyansh App Factory Command Center.

## 00. Executive Summary
Roam is a privacy-first personal location memory app. It helps users remember places they visited, visualize movement, and create a private map or timeline. The end product should include onboarding, map view, timeline/history, local storage, export/delete controls, settings, and clear privacy positioning.

## 01. Product
MVP scope: permission onboarding, map view, timeline/history view, local visit storage, export/delete controls, privacy settings.

## 02. Design
Map-first, calm, private, travel-journal feel. Screens: onboarding, permission rationale, map, timeline, place detail, export/delete, settings.

## 03. Frontend Technical
SwiftUI with MapKit and CoreLocation. Store visits, points, trips, preferences, and retention settings locally.

## 04. Backend Technical
No backend for v1. Future services may include encrypted sync, trip summaries, map enrichment, or remote config.

## 05. Business
Business model: premium local features, export packs, or optional encrypted sync later.

## 06. Marketing
Positioning: your private map memory. Channels: travel journaling, privacy-focused audiences, personal analytics communities.

## 07. User Acquisition
Beta with travelers, quantified-self users, and city explorers. Metrics: permission grant, first recorded visit, weekly map view, export/delete usage, retention.

## 08. Execution
Plan: audit repo, audit permissions, freeze privacy-first MVP, build MapKit view, add timeline/storage, QA/TestFlight.

## 09. QA
Test permission states, app relaunch, map load, timeline load, delete history, export, low-signal behavior, airplane mode, and device sizes.

## 10. Legal / Compliance
Explain what location data is stored, where it is stored, and how it can be deleted/exported. Match privacy labels to final implementation.

## 11. Operations
Release process: internal device test, privacy beta, TestFlight, launch decision. Post-launch: trip summaries, encrypted sync, widgets.
