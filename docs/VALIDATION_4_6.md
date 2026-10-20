# Validation and code review: WDC 4.6

Source baseline: `acec557` (4.5.1+13). Release: 4.6.0+14; display version: 4.6.
Validation date: 2026-10-20.

## Automated checks

- Locked dependencies retained; no dependency upgrades or signing changes.
- Dart formatting and Flutter analysis: passed.
- Full Flutter regression suite: 159 tests passed, including historical measurements,
  field timestamps, geometry, discharge, settings scopes, photo handling, interrupted
  imports, malicious archives, scroll restoration, localisation and input units.
- After final formula-layout adjustments, the affected 4.6 and 4.1 tests were repeated.
- Python release-tool suite: 6 tests passed.
- CITATION.cff validated against the official CFF 1.2.0 JSON schema.
- The existing GitHub checks run the full suite on Linux. The signed release workflow
  additionally verifies package `krv.app`, version/build, non-debuggable APK and the
  preserved signing certificate before publishing.

## New regression coverage

- Six-point coefficients are independent in normal and ice/vegetation tables.
  Checked both numerical results against manually weighted examples and edits through
  the actual settings screen. Copies and the three custom profiles remain independent.
- Legacy shared coefficients migrate to separate maps without changing their values.
  Redundant equal copies are omitted on serialization to preserve archive identity.
- Optional project survives JSON, CSV and KRV; repeated import skips duplicates.
  Exact/partial case-insensitive project search and search reset are checked.
- Discharge ordering is numeric, with alphabetical river/site and ascending creation
  time for ties. Unknown discharge follows numeric values in both directions.
- Ice thickness may be absent, entered as zero, or cleared. Missing data are displayed
  as «н/д» / N/A. Thickness changes do not change discharge.
- Ice profiles require both banks, connect available observations in either chainage
  direction and preserve original data. Bank outlines extend vertically to zero.
- The home ice icon fits between the measurement and warning icons.
- Russian and English settings render on a 360-pixel screen with 1.3 text scaling.

## Reports and visual inspection

Six PDF examples cover Russian/English, narrow tables, wide tables and missing bank
ice data. Parsed every page and rendered the reports with Poppler. Narrow reports
remain portrait; wide velocity tables use landscape, followed by the discharge table
on the same page. Project lines are omitted when empty. Partial ice observations remain
in the sounding table without an ice chart.

Also generated both language reports with 65 distinct formulas (24 pages each) and
verified that the last formula is present. Screenshot inspection covers compact
coefficient tables, formula indices and ice bank outlines.

CSV schema 4.6 has 89 columns for all measurements and both languages. The original
88 columns retain their order; the appended `project` cell is blank when absent.

## Review and conservative cleanup

Reviewed calculation/configuration flow, geometry, persistence, archive validation,
PDF/CSV generation, settings inheritance, translations, Android sharing and release
checks. Removed unused method-key and report helper code, including the former
calculation-block helper that always returned null. Removed obsolete mandatory-ice
validation. Its historical saved flag is retained only for old archive identity.

PDF formula groups/IDs are indexed once per report instead of rebuilding the groups
for every row. The displayed formulas use the same weight maps as the calculation.
No numerical method, geometry algorithm, package identity, dependencies or signing
keys were replaced. Legacy regression tests remain useful and were retained; tests
of renamed labels, CSV column count and optional ice were updated to the new contract.

Automated checks and visual review cannot establish the absence of every possible
defect. Installation and field use on the user's physical Android phone were not
performed in this environment.
