# CSV schema 4.6 — WDC 4.6

UTF-8 BOM, separator `;`, quoted cells with doubled double quotes. Use a CSV parser, not string splitting: comments and JSON may contain separators and line breaks.

Every export uses the same 89 columns, including old measurements and records without ice. The first 72 columns retain the modern 4.x order and fixed Russian headers regardless of interface language. The 17 appended headers are stable ASCII identifiers. Measurements without verticals contain one metadata row with an empty vertical_id. Numeric display cells follow the existing decimal-point convention; numeric values inside JSON follow JSON syntax with decimal points.

`measurement_id` and `vertical_id` identify rows. `ice_thickness_cm` is the measured total ice thickness, not submerged thickness. `geometry_method` distinguishes legacy geometry from `clipped_profile_v44`. Bank modes are `vertical` or `slope`; they only affect rising levels.

`measurement_metadata_json` on the first row contains the complete saved measurement metadata except the list of verticals, including all formula settings, initial method, timestamps, archive origin, comments and photo filenames/captions. `vertical_data_json` contains each complete saved vertical including all velocity timestamps, individual settings and original observations. `calculated_profile_json` on the first row contains derived profile knots and submerged segments. Join metadata by measurement_id when processing batches. Photos themselves are binary files and are transferred in .krv, not embedded into CSV.

Original measurements and calculated geometry are distinct. Water-edge coordinates and extension areas are derived. Blank means absent; a numeric zero is a real value. Preserve JSON columns for lossless numeric/settings analysis. Human-readable labels and warning text may follow the selected language; machine enums and JSON keys are stable.


In WDC 4.5 the schema identifier remains `4.4` because column order and names are unchanged. `app_version` identifies the exporting app (`4.5.0`). Bank mode columns retain the **requested** mode. `calculated_profile_json.fallback_banks` lists sides (`ЛБ`, `ПБ`) actually calculated with a vertical bank because the requested slope could not be extended. `excluded_velocity_vertical_ids` lists dry velocity verticals excluded from Q, while their raw inputs remain present in their normal rows. `discharge_defined` is false when Q is unavailable; the discharge value is null in metadata and its numeric display cell is empty, never a fabricated zero. All corresponding warnings remain in measurement metadata and the warnings column.


In WDC 4.6, `csv_schema_version` is `4.6`. The first 88 columns retain their
positions; the new final column `project` contains the optional project name
on every row, or an empty cell when no project was entered. PDF omits the project
line when empty. Project names and independent special-condition six-point
weights are also preserved in JSON metadata and KRV archives (measurement schema
7 when these features are used). Older measurement schemas remain readable.
Missing ice thickness stays empty in CSV; an entered zero stays numeric zero.
Every entered ice thickness is exported even when the bank data are insufficient
to draw an ice-thickness profile.
