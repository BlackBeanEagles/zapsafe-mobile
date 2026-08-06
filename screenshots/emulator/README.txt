ZapSafe emulator screenshots — what is what
================================================

Folder: zapsafe_mobile/screenshots/emulator/

IMPORTANT: NOT EVERYTHING HERE IS CUSTOMER-FACING
-------------------------------------------------

This repo is a 300-day BUILD TRACKER. Many screens are internal dev tools,
milestones, and mock frontends — NOT what end users install from the App Store.

WHAT YOUR CUSTOMER WOULD SEE (production app)
-----------------------------------------------
- /dashboard          Home: SOS button, protection score, mode card (Day 46-50 spec;
                      main route still uses placeholder until full dashboard ships)
- /onboarding         First-run flow
- /sos-active         SOS in progress
- /settings           User settings
- /vault, /contacts   Core safety features

Customers do NOT open the nav index or Day 300 milestone by default.

WHAT YOU (developer / stakeholder) SEE in these screenshots
-----------------------------------------------------------
01_nav_index_hero.png       DEV nav hub — gold hero + ORANGE PROGRESS BAR (300/365)
02_day300_celebration.png   Internal milestone screen — ring + sections A-E
03_day300_stats_grid.png    Internal stats — 8-box stat grid + timeline
04_day300_phase2.png        Internal Phase 2 preview (Days 301-365)
05_day200_grand_finale.png  Day 200 milestone
06_day298_gonogo_gate.png   Launch checklist
07_day289_regression_runner QA tool — 300-screen test runner
08_customer_dashboard_spec  What /dashboard describes for customers (placeholder)

WHERE THE "BARS" ARE
--------------------
- Linear progress bar (82% to Day 365): 01_nav_index_hero.png
- Circular 300/365 ring:                 02_day300_celebration.png
- Stat number grid (not bar charts):     03_day300_stats_grid.png
- Timeline breadcrumb:                   03_day300_stats_grid.png (scroll down)

To re-capture:
  powershell -File tools/capture_one_screenshot.ps1 -Name "03_day300_stats_grid.png" -Route "/day-300-milestone" -ExtraDefine "INITIAL_TAB=1"
