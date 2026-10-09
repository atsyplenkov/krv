# CSV 4.4

UTF-8 BOM, separator `;`, quoted cells with doubled double quotes. Use a CSV parser, not string splitting: comments and JSON may contain separators and line breaks.

Every export uses the same 88 columns, including old measurements and records without ice. The first 72 columns retain the modern 4.x order and fixed Russian headers regardless of interface language. The 16 appended headers are stable ASCII identifiers. Measurements without verticals contain one metadata row with an empty vertical_id. Numeric display cells follow the existing decimal-point convention; numeric values inside JSON follow JSON syntax with decimal points.

`measurement_id` and `vertical_id` identify rows. `ice_thickness_cm` is the measured total ice thickness, not submerged thickness. `geometry_method` distinguishes legacy geometry from `clipped_profile_v44`. Bank modes are `vertical` or `slope`; they only affect rising levels.

`measurement_metadata_json` on the first row contains the complete saved measurement metadata except the list of verticals, including all formula settings, initial method, timestamps, archive origin, comments and photo filenames/captions. `vertical_data_json` contains each complete saved vertical including all velocity timestamps, individual settings and original observations. `calculated_profile_json` on the first row contains derived profile knots and submerged segments. Join metadata by measurement_id when processing batches. Photos themselves are binary files and are transferred in .krv, not embedded into CSV.

Original measurements and calculated geometry are distinct. Water-edge coordinates and extension areas are derived. Blank means absent; a numeric zero is a real value. Preserve JSON columns for lossless numeric/settings analysis. Human-readable labels and warning text may follow the selected language; machine enums and JSON keys are stable.
