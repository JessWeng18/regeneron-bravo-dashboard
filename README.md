# regeneron-bravo-dashboard
Visualization of global clinical trial trends using Preset.io

This repository contains an exported Preset.io (Apache Superset) dashboard for archival and future import.

## Contents
- `dashboards/`: YAML files defining dashboard layouts and metadata
- `charts/`: YAML files containing chart configuration used in dashboards
- `datasets/`: YAML files defining dataset-level SQL logic and metadata (e.g., filters, metrics, groupbys)
- `databases/`: YAML files with database metadata (excluding credentials)
- `metadata.yaml`: Export metadata for import version tracking


## How to Re-Import
1. In a Superset instance, go to:
   - `Settings` → `Import Dashboards`
2. Upload the entire exported zip file or the extracted directory
3. Reconnect to the appropriate data source as needed

## Notes
- Database credentials and raw data are not included.
- This export is from Preset.io (Entrepreneurship plan).
