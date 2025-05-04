WITH cleaned AS (
  SELECT
    e.nct_id,
    regexp_replace(e.criteria, '(?i)(Exclusion Criteria|Exclusion).*', '', 'g') AS inclusion_text
  FROM ctgov.eligibilities e
  WHERE e.criteria IS NOT NULL
),
star_counts AS (
  SELECT
    nct_id,
    array_length(string_to_array(inclusion_text, '*'), 1) - 1 AS star_count,
    inclusion_text
  FROM cleaned
),
numbered_counts AS (
  SELECT 
    e.nct_id,
    MAX((m.num_match[1])::BIGINT) AS numbered_count
  FROM cleaned e,
  LATERAL regexp_matches(e.inclusion_text, '([0-9]+)\.', 'g') AS m(num_match)
  WHERE LENGTH(m.num_match[1]) <= 3
  GROUP BY e.nct_id
),
combined AS (
  SELECT
    s.nct_id,
    GREATEST(COALESCE(s.star_count, 0), COALESCE(n.numbered_count, 0)) AS inclusion_criteria_count
  FROM star_counts s
  LEFT JOIN numbered_counts n ON s.nct_id = n.nct_id
),
binned AS (
  SELECT
    nct_id,
    inclusion_criteria_count,
    CASE 
      WHEN inclusion_criteria_count BETWEEN 0 AND 5 THEN '0–5'
      WHEN inclusion_criteria_count BETWEEN 6 AND 10 THEN '6–10'
      WHEN inclusion_criteria_count BETWEEN 11 AND 15 THEN '11–15'
      WHEN inclusion_criteria_count BETWEEN 16 AND 25 THEN '16–25'
      WHEN inclusion_criteria_count > 25 THEN '26+'
      ELSE 'Unknown'
    END AS criteria_bin
  FROM combined
),
study_years AS (
  SELECT 
    nct_id,
    EXTRACT(YEAR FROM start_date) AS year
  FROM ctgov.studies
),
study_year_counts AS (
  SELECT 
    nct_id,
    year,
    COUNT(*) OVER (PARTITION BY year) AS trial_count
  FROM study_years
),
study_details AS (
  SELECT
    nct_id,
    (DATE_PART('year', completion_date) - DATE_PART('year', start_date)) * 12 +
    (DATE_PART('month', completion_date) - DATE_PART('month', start_date)) AS month_difference,
    target_duration,
    study_type,
    acronym,
    overall_status,
    phase,
    enrollment,
    source_class,
    official_title,
    start_date,
    completion_date
  FROM ctgov.studies
),
study_countries AS (
  SELECT 
    s.nct_id, 
    c.name AS country_name
  FROM ctgov.studies s
  JOIN ctgov.countries c ON s.nct_id = c.nct_id
),
study_phases AS (
  SELECT 
    nct_id,
    UNNEST(STRING_TO_ARRAY(phase, '/')) AS phase_cleaned
  FROM ctgov.studies
),
study_conditions AS (
  SELECT
    nct_id,
    UPPER(SPLIT_PART(name, ' ', 1)) AS condition_name
  FROM ctgov.conditions
),
study_sponsors AS (
  SELECT
    nct_id,
    agency_class,
    name AS sponsor_name
  FROM ctgov.sponsors
),
termination_rate AS (
  SELECT 
    s.nct_id as nct_id,
    criteria_bin,
    ROUND(
      100.0 * SUM(CASE WHEN overall_status = 'TERMINATED' THEN 1 ELSE 0 END)::numeric / COUNT(*), 
      2
    ) AS termination_rate_percent
  FROM binned b
  JOIN ctgov.studies s ON b.nct_id = s.nct_id
  GROUP BY s.nct_id, criteria_bin
)

SELECT 
  sy.nct_id,
  sy.trial_count,
  sy.year,
  sd.month_difference,
  sd.target_duration,
  sd.study_type,
  sd.acronym,
  sd.overall_status,
  sd.phase,
  sp.phase_cleaned,
  sd.enrollment,
  sd.source_class,
  sc.country_name,
  scn.condition_name,
  ss.agency_class,
  ss.sponsor_name,
  b.criteria_bin,
  tr.termination_rate_percent
FROM study_year_counts sy
JOIN study_details sd ON sy.nct_id = sd.nct_id
LEFT JOIN study_countries sc ON sy.nct_id = sc.nct_id
LEFT JOIN study_phases sp ON sy.nct_id = sp.nct_id
LEFT JOIN study_conditions scn ON sy.nct_id = scn.nct_id
LEFT JOIN study_sponsors ss ON sy.nct_id = ss.nct_id
LEFT JOIN binned b ON sy.nct_id = b.nct_id
LEFT JOIN termination_rate tr ON sy.nct_id = tr.nct_id
GROUP BY sy.nct_id, sy.trial_count, sy.year, sd.month_difference, sd.target_duration, sd.study_type, 
    sd.acronym, sd.overall_status, sd.phase, sp.phase_cleaned, 
    sd.enrollment, sd.source_class, sd.official_title, sc.country_name, scn.condition_name, ss.agency_class, ss.sponsor_name, b.criteria_bin, tr.termination_rate_percent;

--end of code
