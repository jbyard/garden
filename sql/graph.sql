CREATE SCHEMA IF NOT EXISTS garden;

CREATE OR REPLACE VIEW garden.contributions AS
WITH date_range (ts) AS (
	SELECT generate_series(

		/* Start of the week, this day, last year */
		date_trunc('week',(NOW() - '1 year'::interval)::date + 1 )::date - 1,

		/* End of the week this year */
		date_trunc('week',(NOW() + '1 week'::interval)::date + 1)::date - 2,
		'1 day'::interval
	)
)

SELECT * FROM (
	SELECT 
		0 AS rn,
		NULL::INTEGER AS contributions,
		NULL::date AS date,
		'header' AS class,
		CASE WHEN lag(date_trunc('month',ts)) OVER (ORDER BY ts) =
		date_trunc('month',ts) THEN NULL ELSE to_char(ts,'Mon') END AS label,
		NULL::TEXT AS details
	FROM date_range
	WHERE extract(dow FROM ts) = 0
	ORDER BY ts
) AS month_header

UNION ALL

SELECT
	rn,
	contributions,
	date,
	/* Frost date lines based on Portland Maine */
	CASE WHEN date_trunc('week',date + 1)::date = 
		date_trunc('week',('5/5/' || EXTRACT('year' FROM date))::DATE)
		THEN class || ' last_frost'
	WHEN date_trunc('week',date + 1)::date =
		date_trunc('week',('10/5/' || EXTRACT('year' FROM date))::DATE)
	THEN class || ' first_frost' ELSE class END AS class,
	label,
	details
FROM (
	SELECT
		extract(dow FROM d.ts)::INTEGER + 1 AS rn,
		COUNT(l.*)::INTEGER AS contributions,
		d.ts::date AS date,
		CASE WHEN d.ts::date < NOW()::date - '1 year'::interval OR d.ts > NOW()
		THEN NULL
		WHEN COUNT(l.*) = 0 THEN 'none'
		WHEN COUNT(l.*) < 7 THEN 'light'
		WHEN COUNT(l.*) < 14 THEN 'medium'
		WHEN COUNT(l.*) < 21 THEN 'heavy'
		ELSE 'dank' END AS class,
		NULL::TEXT AS label,
		to_char(d.ts,'Day Mon DD, YYYY') AS details
	FROM date_range d
	LEFT JOIN garden.ledger l      ON d.ts = date_trunc('day',l.ts)
	LEFT JOIN garden.actions a     USING (action)
	LEFT JOIN garden.plants p      USING (plant)
	LEFT JOIN garden.varieties v   USING (variety)
	LEFT JOIN garden.beds b        USING (bed)
	GROUP BY d.ts
	ORDER BY extract(dow FROM d.ts), d.ts
) AS day_cells

UNION ALL

SELECT * FROM (
	SELECT
		8 AS rn,
		NULL::INTEGER AS contributions,
		NULL::date AS date,
		NULL::TEXT AS class,
		NULL::TEXT AS label,
		NULL::TEXT AS details
) AS spacer

UNION ALL

SELECT * FROM ( VALUES
(9,NULL::INTEGER,NULL::date,'none',NULL::TEXT,'No contributions'),
(9,NULL::INTEGER,NULL::date,'light',NULL::TEXT,'0-6 contributions'),
(9,NULL::INTEGER,NULL::date,'medium',NULL::TEXT,'7-13 contributions'),
(9,NULL::INTEGER,NULL::date,'heavy',NULL::TEXT,'14-20 contributions'),
(9,NULL::INTEGER,NULL::date,'dank',NULL::TEXT,'21+ contributions')
) AS legend;
COMMENT ON VIEW garden.contributions IS
'Contribution graph of the past year''s garden activity.';
