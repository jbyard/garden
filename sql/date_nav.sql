CREATE SCHEMA IF NOT EXISTS garden;

CREATE OR REPLACE FUNCTION garden.date_nav(DATE DEFAULT NOW()::DATE)
RETURNS TABLE (
	previous   DATE,
	selected   DATE,
	next       DATE
) AS $$
DECLARE
	previous   DATE;
	next       DATE;
BEGIN
	/* Most recent activity prior to the selected date */
	SELECT ts::DATE
	FROM garden.ledger WHERE ts < $1
	ORDER BY ts DESC LIMIT 1 INTO previous;

	/* Earliest activity after the selected date */
	SELECT ts::DATE
	FROM garden.ledger WHERE ts > $1
	ORDER BY ts LIMIT 1 INTO next;

	RETURN QUERY SELECT previous, $1, next;
END;
$$ LANGUAGE PLPGSQL;

COMMENT ON FUNCTION garden.date_nav IS
'Pervious and next dates with garden activity from a selected date'; 
